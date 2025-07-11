// src/services/chat.service.js
import Mensaje from "../entity/mensaje.entity.js";
import User from "../entity/user.entity.js";
import ChatPersonal from "../entity/chatPersonal.entity.js";
import ChatGrupal from "../entity/chatGrupal.entity.js";
import { AppDataSource } from "../config/configDb.js";
import { procesarMensajeTemporal } from "./chatDistribuidor.service.js";
import Viaje from "../entity/viaje.entity.js";
import mongoose from "mongoose";

const mensajeRepository = AppDataSource.getRepository(Mensaje);
const userRepository = AppDataSource.getRepository(User);
const chatPersonalRepository = AppDataSource.getRepository(ChatPersonal);
const chatGrupalRepository = AppDataSource.getRepository(ChatGrupal);

export async function enviarMensaje(rutEmisor, contenido, rutReceptor = null, idViajeMongo = null) {
  try {
    const emisor = await userRepository.findOne({ where: { rut: rutEmisor } });
    if (!emisor) {
      throw new Error("El emisor no existe.");
    }

    const nuevoMensaje = mensajeRepository.create({ contenido, emisor });

    if (rutReceptor && idViajeMongo) {
      throw new Error("No se puede especificar un receptor y un ID de viaje a la vez. Un mensaje debe ser 1 a 1 o de viaje.");
    } else if (rutReceptor) {
      const receptor = await userRepository.findOne({ where: { rut: rutReceptor } });
      if (!receptor) {
        throw new Error("El receptor no existe.");
      }
      nuevoMensaje.receptor = receptor;
      nuevoMensaje.idViajeMongo = null;
    } else if (idViajeMongo) {
      if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
        throw new Error("El ID de viaje proporcionado no es un ObjectId válido.");
      }

      const viaje = await Viaje.findById(idViajeMongo);
      if (!viaje || (viaje.estado !== "activo" && viaje.estado !== "en_curso")) {
        throw new Error("El viaje no existe o no está activo/en curso para chatear.");
      }

      const esConductor = viaje.usuario_rut === rutEmisor;
      const esPasajeroConfirmado = viaje.pasajeros.some(
        (p) => p.usuario_rut === rutEmisor && p.estado === 'confirmado'
      );

      if (!esConductor && !esPasajeroConfirmado) {
        throw new Error("No eres un participante confirmado de este viaje para enviar mensajes.");
      }

      nuevoMensaje.idViajeMongo = idViajeMongo;
      nuevoMensaje.receptor = null;
    } else {
      throw new Error("Se debe especificar un 'rutReceptor' (para chat 1 a 1) o un 'idViajeMongo' (para chat grupal de viaje).");
    }

    // Guardar en temporal
    const mensajeGuardado = await mensajeRepository.save(nuevoMensaje);

    // Procesar inmediatamente con el distribuidor
    const mensajeProcesado = await procesarMensajeTemporal(mensajeGuardado);

    return mensajeProcesado;
  } catch (error) {
    console.error("Error al enviar el mensaje:", error.message);
    throw new Error(`Error al enviar el mensaje: ${error.message}`);
  }
}

export async function obtenerConversacion(rutUsuario1, rutUsuario2) {
  try {
    const rutMenor = rutUsuario1 < rutUsuario2 ? rutUsuario1 : rutUsuario2;
    const rutMayor = rutUsuario1 < rutUsuario2 ? rutUsuario2 : rutUsuario1;
    const identificadorChat = `${rutMenor}-${rutMayor}`;

    const chatPersonal = await chatPersonalRepository.findOne({
      where: { identificadorChat },
      relations: ["usuario1", "usuario2"],
    });

    if (!chatPersonal) {
      return [];
    }

    // Filtrar mensajes no eliminados
    const mensajesFiltrados = chatPersonal.chatCompleto.filter(mensaje => !mensaje.eliminado);
    
    return mensajesFiltrados;
  } catch (error) {
    console.error("Error al obtener la conversación 1 a 1:", error.message);
    throw new Error(`Error al obtener la conversación 1 a 1: ${error.message}`);
  }
}

export async function obtenerMensajesViaje(idViajeMongo, rutUsuarioSolicitante) {
  try {
    if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
      throw new Error("El ID de viaje proporcionado no es un ObjectId válido.");
    }

    const viaje = await Viaje.findById(idViajeMongo);
    if (!viaje || (viaje.estado !== "activo" && viaje.estado !== "en_curso")) {
      throw new Error("El viaje no existe o no está activo/en curso.");
    }

    const esConductor = viaje.usuario_rut === rutUsuarioSolicitante;
    const esPasajeroConfirmado = viaje.pasajeros.some(
      (p) => p.usuario_rut === rutUsuarioSolicitante && p.estado === 'confirmado'
    );

    if (!esConductor && !esPasajeroConfirmado) {
      throw new Error("No tienes permiso para ver los mensajes de este viaje.");
    }

    const chatGrupal = await chatGrupalRepository.findOne({
      where: { idViajeMongo },
    });

    if (!chatGrupal) {
      return [];
    }

    const mensajesFiltrados = chatGrupal.chatCompleto.filter(mensaje => !mensaje.eliminado);
    
    return mensajesFiltrados;
  } catch (error) {
    console.error("Error al obtener los mensajes del viaje:", error.message);
    throw new Error(`Error al obtener los mensajes del viaje: ${error.message}`);
  }
}

export async function editarMensaje(idMensaje, rutEmisor, nuevoContenido) {
  try {
    // Buscar en chat personal primero
    const chatPersonal = await chatPersonalRepository
      .createQueryBuilder("chat")
      .where("(chat.rutUsuario1 = :rut OR chat.rutUsuario2 = :rut)", { rut: rutEmisor })
      .getMany();

    // Buscar el mensaje en los chats personales
    for (const chat of chatPersonal) {
      const mensajes = [...chat.chatCompleto];
      const mensajeIndex = mensajes.findIndex(m => m.id == idMensaje);
      
      if (mensajeIndex !== -1) {
        if (mensajes[mensajeIndex].emisor !== rutEmisor) {
          throw new Error("No tienes permiso para editar este mensaje.");
        }

        mensajes[mensajeIndex].contenido = nuevoContenido;
        mensajes[mensajeIndex].editado = true;

        await chatPersonalRepository.update(chat.id, {
          chatCompleto: mensajes,
          fechaUltimaActualizacion: new Date()
        });

        // Retornar mensaje editado con información del receptor
        const mensajeEditado = mensajes[mensajeIndex];
        const receptor = chat.rutUsuario1 === rutEmisor ? chat.rutUsuario2 : chat.rutUsuario1;
        
        return {
          ...mensajeEditado,
          receptor: receptor,
          idViajeMongo: null
        };
      }
    }

    // Buscar en chat grupal
    const chatGrupal = await chatGrupalRepository
      .createQueryBuilder("chat")
      .getMany();

    for (const chat of chatGrupal) {
      const mensajes = [...chat.chatCompleto];
      const mensajeIndex = mensajes.findIndex(m => m.id == idMensaje);
      
      if (mensajeIndex !== -1) {
        const viaje = await Viaje.findById(chat.idViajeMongo);
        if (!viaje || (viaje.estado !== "activo" && viaje.estado !== "en_curso")) {
          throw new Error("El mensaje pertenece a un viaje que no está activo/en curso y no puede ser editado.");
        }

        if (mensajes[mensajeIndex].emisor !== rutEmisor) {
          throw new Error("No tienes permiso para editar este mensaje.");
        }

        mensajes[mensajeIndex].contenido = nuevoContenido;
        mensajes[mensajeIndex].editado = true;

        await chatGrupalRepository.update(chat.id, {
          chatCompleto: mensajes,
          fechaUltimaActualizacion: new Date()
        });

        // Retornar mensaje editado con información del viaje
        const mensajeEditado = mensajes[mensajeIndex];
        
        return {
          ...mensajeEditado,
          receptor: null,
          idViajeMongo: chat.idViajeMongo
        };
      }
    }

    throw new Error("Mensaje no encontrado.");
  } catch (error) {
    console.error("Error al editar el mensaje:", error.message);
    throw new Error(`Error al editar el mensaje: ${error.message}`);
  }
}

export async function eliminarMensaje(idMensaje, rutEmisor) {
  try {
    // Buscar en chat personal primero
    const chatPersonal = await chatPersonalRepository
      .createQueryBuilder("chat")
      .where("(chat.rutUsuario1 = :rut OR chat.rutUsuario2 = :rut)", { rut: rutEmisor })
      .getMany();

    // Buscar el mensaje en los chats personales
    for (const chat of chatPersonal) {
      const mensajes = [...chat.chatCompleto];
      const mensajeIndex = mensajes.findIndex(m => m.id == idMensaje);
      
      if (mensajeIndex !== -1) {
        if (mensajes[mensajeIndex].emisor !== rutEmisor) {
          throw new Error("No tienes permiso para eliminar este mensaje.");
        }

        mensajes[mensajeIndex].eliminado = true;

        await chatPersonalRepository.update(chat.id, {
          chatCompleto: mensajes,
          fechaUltimaActualizacion: new Date()
        });

        // Retornar información del mensaje eliminado incluyendo receptor
        const mensajeEliminado = mensajes[mensajeIndex];
        const receptor = chat.rutUsuario1 === rutEmisor ? chat.rutUsuario2 : chat.rutUsuario1;
        
        return { 
          mensaje: "Mensaje eliminado exitosamente",
          mensajeEliminado: {
            id: mensajeEliminado.id,
            emisor: mensajeEliminado.emisor,
            receptor: receptor,
            esChat1a1: true
          }
        };
      }
    }

    // Buscar en chat grupal
    const chatGrupal = await chatGrupalRepository
      .createQueryBuilder("chat")
      .getMany();

    for (const chat of chatGrupal) {
      const mensajes = [...chat.chatCompleto];
      const mensajeIndex = mensajes.findIndex(m => m.id == idMensaje);
      
      if (mensajeIndex !== -1) {
        const viaje = await Viaje.findById(chat.idViajeMongo);
        if (!viaje || (viaje.estado !== "activo" && viaje.estado !== "en_curso")) {
          throw new Error("El mensaje pertenece a un viaje que no está activo/en curso y no puede ser eliminado.");
        }

        if (mensajes[mensajeIndex].emisor !== rutEmisor) {
          throw new Error("No tienes permiso para eliminar este mensaje.");
        }

        mensajes[mensajeIndex].eliminado = true;

        await chatGrupalRepository.update(chat.id, {
          chatCompleto: mensajes,
          fechaUltimaActualizacion: new Date()
        });

        // Retornar información del mensaje eliminado para chat grupal
        const mensajeEliminado = mensajes[mensajeIndex];
        
        return { 
          mensaje: "Mensaje eliminado exitosamente",
          mensajeEliminado: {
            id: mensajeEliminado.id,
            emisor: mensajeEliminado.emisor,
            idViajeMongo: chat.idViajeMongo,
            esChat1a1: false
          }
        };
      }
    }

    throw new Error("Mensaje no encontrado.");
  } catch (error) {
    console.error("Error al eliminar el mensaje:", error.message);
    throw new Error(`Error al eliminar el mensaje: ${error.message}`);
  }
}

export async function buscarMensajesEnConversacion(rutUsuario1, rutUsuario2, textoBusqueda) {
  try {
    const rutMenor = rutUsuario1 < rutUsuario2 ? rutUsuario1 : rutUsuario2;
    const rutMayor = rutUsuario1 < rutUsuario2 ? rutUsuario2 : rutUsuario1;
    const identificadorChat = `${rutMenor}-${rutMayor}`;

    const chatPersonal = await chatPersonalRepository.findOne({
      where: { identificadorChat },
      relations: ["usuario1", "usuario2"],
    });

    if (!chatPersonal) {
      return [];
    }

    // Buscar en el JSON del chat completo
    const mensajesEncontrados = chatPersonal.chatCompleto.filter(mensaje => 
      !mensaje.eliminado && 
      mensaje.contenido.toLowerCase().includes(textoBusqueda.toLowerCase())
    );

    return mensajesEncontrados;
  } catch (error) {
    console.error("Error al buscar mensajes en conversación:", error.message);
    throw new Error(`Error al buscar mensajes en conversación: ${error.message}`);
  }
}

export async function buscarMensajesEnViaje(idViajeMongo, rutUsuarioSolicitante, textoBusqueda) {
  try {
    if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
      throw new Error("El ID de viaje proporcionado no es un ObjectId válido.");
    }

    const viaje = await Viaje.findById(idViajeMongo);
    if (!viaje || (viaje.estado !== "activo" && viaje.estado !== "en_curso")) {
      throw new Error("El viaje no existe o no está activo/en curso.");
    }

    const esConductor = viaje.usuario_rut === rutUsuarioSolicitante;
    const esPasajeroConfirmado = viaje.pasajeros.some(
      (p) => p.usuario_rut === rutUsuarioSolicitante && p.estado === 'confirmado'
    );

    if (!esConductor && !esPasajeroConfirmado) {
      throw new Error("No tienes permiso para buscar mensajes en este viaje.");
    }

    const chatGrupal = await chatGrupalRepository.findOne({
      where: { idViajeMongo },
    });

    if (!chatGrupal) {
      return [];
    }

    const mensajesEncontrados = chatGrupal.chatCompleto.filter(mensaje => 
      !mensaje.eliminado && 
      mensaje.contenido.toLowerCase().includes(textoBusqueda.toLowerCase())
    );

    return mensajesEncontrados;
  } catch (error) {
    console.error("Error al buscar mensajes en viaje:", error.message);
    throw new Error(`Error al buscar mensajes en viaje: ${error.message}`);
  }
}

export async function obtenerChatsUsuario(rutUsuario) {
  try {
    const chatsPersonales = await chatPersonalRepository.find({
      where: [
        { rutUsuario1: rutUsuario, eliminado: false },
        { rutUsuario2: rutUsuario, eliminado: false },
      ],
      relations: ["usuario1", "usuario2"],
      order: { fechaUltimaActualizacion: "DESC" },
    });

    const chatsGrupales = await chatGrupalRepository
      .createQueryBuilder("chat")
      .where("JSON_CONTAINS(chat.participantes, :rutUsuario)", { rutUsuario: `"${rutUsuario}"` })
      .andWhere("chat.eliminado = false")
      .orderBy("chat.fechaUltimaActualizacion", "DESC")
      .getMany();

    return {
      chatsPersonales,
      chatsGrupales,
    };
  } catch (error) {
    console.error("Error al obtener chats del usuario:", error.message);
    throw new Error(`Error al obtener chats del usuario: ${error.message}`);
  }
}