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
    console.log(`📩 ENVIANDO MENSAJE: ${rutEmisor} → ${rutReceptor || idViajeMongo}`);
    console.log(`📱 DEVICE DEBUG - Parámetros recibidos:`, {
      rutEmisor,
      contenido,
      rutReceptor,
      idViajeMongo,
      timestamp: new Date().toISOString()
    });
    
    const emisor = await userRepository.findOne({ where: { rut: rutEmisor } });
    if (!emisor) {
      console.error(`❌ DEVICE DEBUG - Emisor no encontrado: ${rutEmisor}`);
      throw new Error("El emisor no existe.");
    }
    console.log(`✅ DEVICE DEBUG - Emisor encontrado: ${emisor.rut}`);
    

    const nuevoMensaje = mensajeRepository.create({ contenido, emisor });

    if (rutReceptor && idViajeMongo) {
      console.error(`❌ DEVICE DEBUG - Error: receptor y viaje especificados al mismo tiempo`);
      throw new Error("No se puede especificar un receptor y un ID de viaje a la vez. Un mensaje debe ser 1 a 1 o de viaje.");
    } else if (rutReceptor) {
      console.log(`📱 DEVICE DEBUG - Procesando mensaje personal a ${rutReceptor}`);
      const receptor = await userRepository.findOne({ where: { rut: rutReceptor } });
      if (!receptor) {
        console.error(`❌ DEVICE DEBUG - Receptor no encontrado: ${rutReceptor}`);
        throw new Error("El receptor no existe.");
      }
      console.log(`✅ DEVICE DEBUG - Receptor encontrado: ${receptor.rut}`);
      nuevoMensaje.receptor = receptor;
      nuevoMensaje.idViajeMongo = null;
    } else if (idViajeMongo) {
      console.log(`📱 DEVICE DEBUG - Procesando mensaje grupal para viaje ${idViajeMongo}`);
      if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
        console.error(`❌ DEVICE DEBUG - ID de viaje inválido: ${idViajeMongo}`);
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
      console.error(`❌ DEVICE DEBUG - No se especificó receptor ni viaje`);
      throw new Error("Se debe especificar un 'rutReceptor' (para chat 1 a 1) o un 'idViajeMongo' (para chat grupal de viaje).");
    }

    // Guardar en temporal
    console.log(`📱 DEVICE DEBUG - Guardando mensaje en BD temporal...`);
    const mensajeGuardado = await mensajeRepository.save(nuevoMensaje);
    console.log(`💾 MENSAJE GUARDADO: ID=${mensajeGuardado.id}, Emisor=${rutEmisor}, Receptor=${rutReceptor || idViajeMongo}`);
    console.log(`📱 DEVICE DEBUG - Mensaje guardado exitosamente, ID: ${mensajeGuardado.id}`);

    // Procesar inmediatamente con el distribuidor
    console.log(`📱 DEVICE DEBUG - Iniciando procesamiento del mensaje...`);
    const mensajeProcesado = await procesarMensajeTemporal(mensajeGuardado);
    console.log(`📱 DEVICE DEBUG - Resultado del procesamiento:`, mensajeProcesado);
    console.log(`✅ MENSAJE PROCESADO: ID=${mensajeProcesado.id}, Tipo=${mensajeProcesado.tipo}`);

    return mensajeProcesado;
  } catch (error) {
    console.error(`❌ DEVICE DEBUG - Error en enviarMensaje:`, {
      rutEmisor,
      rutReceptor,
      idViajeMongo,
      error: error.message,
      stack: error.stack
    });
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
    console.log(`📝 EDITANDO MENSAJE: ID=${idMensaje}, Editor=${rutEmisor}`);
    console.log(`📱 DEVICE DEBUG - Editando mensaje: ID=${idMensaje}, Editor=${rutEmisor}, Contenido="${nuevoContenido}"`);
    
    // BÚSQUEDA OPTIMIZADA: Buscar en todos los chats pero con lógica mejorada
    const chatPersonal = await chatPersonalRepository
      .createQueryBuilder("chat")
      .where("(chat.rutUsuario1 = :rut OR chat.rutUsuario2 = :rut)", { rut: rutEmisor })
      .getMany();

    console.log(`🔍 Chats encontrados para ${rutEmisor}: ${chatPersonal.length}`);
    console.log(`📱 DEVICE DEBUG - Chats personales encontrados: ${chatPersonal.length}`);

    // Buscar el mensaje en los chats personales
    for (const chat of chatPersonal) {
      console.log(`📱 DEVICE DEBUG - Buscando en chat: ${chat.idChat}`);
      const mensajes = [...chat.chatCompleto];
      const mensajeIndex = mensajes.findIndex(m => m.id == idMensaje);
      
      console.log(`🔍 Buscando mensaje ${idMensaje} en chat ${chat.identificadorChat}: ${mensajeIndex !== -1 ? 'ENCONTRADO' : 'NO ENCONTRADO'}`);
      console.log(`📱 DEVICE DEBUG - Mensaje ${idMensaje} en chat ${chat.identificadorChat}: ${mensajeIndex !== -1 ? 'ENCONTRADO' : 'NO ENCONTRADO'}`);
      
      if (mensajeIndex !== -1) {
        console.log(`📋 Mensaje encontrado: Emisor=${mensajes[mensajeIndex].emisor}, Editor=${rutEmisor}`);
        console.log(`📱 DEVICE DEBUG - Mensaje encontrado: Emisor=${mensajes[mensajeIndex].emisor}, Editor=${rutEmisor}`);
        
        if (mensajes[mensajeIndex].emisor !== rutEmisor) {
          console.error(`❌ DEVICE DEBUG - Sin permisos para editar: Emisor=${mensajes[mensajeIndex].emisor}, Editor=${rutEmisor}`);
          throw new Error("No tienes permiso para editar este mensaje.");
        }

        console.log(`📱 DEVICE DEBUG - Aplicando edición al mensaje ${idMensaje}`);
        mensajes[mensajeIndex].contenido = nuevoContenido;
        mensajes[mensajeIndex].editado = true;

        console.log(`📱 DEVICE DEBUG - Actualizando chat en BD...`);
        await chatPersonalRepository.update(chat.id, {
          chatCompleto: mensajes,
          fechaUltimaActualizacion: new Date()
        });
        console.log(`📱 DEVICE DEBUG - Chat actualizado exitosamente`);

        // Retornar mensaje con información del chat
        return {
          ...mensajes[mensajeIndex],
          receptor: chat.rutUsuario1 === rutEmisor ? chat.rutUsuario2 : chat.rutUsuario1,
          idViajeMongo: null,
          tipo: "personal"
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

        // Retornar mensaje con información del chat
        return {
          ...mensajes[mensajeIndex],
          receptor: null,
          idViajeMongo: chat.idViajeMongo,
          tipo: "grupal"
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

        return { mensaje: "Mensaje eliminado exitosamente" };
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

        return { mensaje: "Mensaje eliminado exitosamente" };
      }
    }

    throw new Error("Mensaje no encontrado.");
  } catch (error) {
    console.error("Error al eliminar el mensaje:", error.message);
    throw new Error(`Error al eliminar el mensaje: ${error.message}`);
  }
}

/**
 * Obtiene información del mensaje antes de eliminarlo (para WebSocket)
 * @param {number} idMensaje 
 * @param {string} rutEmisor 
 * @returns {Promise<Object|null>}
 */
export async function obtenerInfoMensajeParaEliminacion(idMensaje, rutEmisor) {
  try {
    // Buscar en chat personal primero
    const chatPersonal = await chatPersonalRepository
      .createQueryBuilder("chat")
      .where("(chat.rutUsuario1 = :rut OR chat.rutUsuario2 = :rut)", { rut: rutEmisor })
      .getMany();

    // Buscar el mensaje en los chats personales
    for (const chat of chatPersonal) {
      const mensajes = [...chat.chatCompleto];
      const mensaje = mensajes.find(m => m.id == idMensaje);
      
      if (mensaje) {
        if (mensaje.emisor !== rutEmisor) {
          return null; // No tiene permisos
        }

        return {
          id: mensaje.id,
          tipo: "personal",
          emisor: mensaje.emisor,
          receptor: mensaje.receptor || (chat.rutUsuario1 === rutEmisor ? chat.rutUsuario2 : chat.rutUsuario1),
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
      const mensaje = mensajes.find(m => m.id == idMensaje);
      
      if (mensaje) {
        const viaje = await Viaje.findById(chat.idViajeMongo);
        if (!viaje || (viaje.estado !== "activo" && viaje.estado !== "en_curso")) {
          return null; // Viaje no activo
        }

        if (mensaje.emisor !== rutEmisor) {
          return null; // No tiene permisos
        }

        return {
          id: mensaje.id,
          tipo: "grupal",
          emisor: mensaje.emisor,
          receptor: null,
          idViajeMongo: chat.idViajeMongo
        };
      }
    }

    return null; // No encontrado
  } catch (error) {
    console.error("Error al obtener info del mensaje:", error.message);
    return null;
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