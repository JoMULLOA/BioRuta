// src/services/chatDistribuidor.service.js
import { AppDataSource } from "../config/configDb.js";
import Mensaje from "../entity/mensaje.entity.js";
import ChatPersonal from "../entity/chatPersonal.entity.js";
import ChatGrupal from "../entity/chatGrupal.entity.js";
import User from "../entity/user.entity.js";
import { emitToUser, emitToViaje } from "../socket.js";

// Repositorios
const mensajeRepository = AppDataSource.getRepository(Mensaje);
const chatPersonalRepository = AppDataSource.getRepository(ChatPersonal);
const chatGrupalRepository = AppDataSource.getRepository(ChatGrupal);
const userRepository = AppDataSource.getRepository(User);

/**
 * Procesa un mensaje temporal y lo distribuye a su chat definitivo
 * @param {Object} mensajeTemporal - Mensaje desde tabla temporal
 * @returns {Promise<Object>} Mensaje procesado y guardado
 */
export async function procesarMensajeTemporal(mensajeTemporal) {
  try {
    // Determinar tipo de chat
    const esChat1a1 = mensajeTemporal.receptor && !mensajeTemporal.idViajeMongo;
    const esChatGrupal = !mensajeTemporal.receptor && mensajeTemporal.idViajeMongo;

    if (esChat1a1) {
      return await procesarMensajePersonal(mensajeTemporal);
    } else if (esChatGrupal) {
      return await procesarMensajeGrupal(mensajeTemporal);
    } else {
      throw new Error("Tipo de mensaje no válido");
    }
  } catch (error) {
    console.error("Error al procesar mensaje temporal:", error.message);
    throw error;
  }
}

/**
 * Procesa un mensaje para chat 1 a 1
 * @param {Object} mensajeTemporal 
 * @returns {Promise<Object>}
 */
async function procesarMensajePersonal(mensajeTemporal) {
  try {
    const rutEmisor = mensajeTemporal.emisor.rut;
    const rutReceptor = mensajeTemporal.receptor.rut;
    
    // Crear identificador único (menor RUT primero)
    const identificadorChat = crearIdentificadorChat(rutEmisor, rutReceptor);
    
    // Buscar o crear chat personal
    let chatPersonal = await chatPersonalRepository.findOne({
      where: { identificadorChat },
      relations: ["usuario1", "usuario2"]
    });

    if (!chatPersonal) {
      // Crear nuevo chat personal
      chatPersonal = await crearNuevoChatPersonal(rutEmisor, rutReceptor, identificadorChat);
    }

    // Preparar mensaje para agregar al chat
    const mensajeParaChat = {
      id: mensajeTemporal.id,
      contenido: mensajeTemporal.contenido,
      emisor: rutEmisor,
      receptor: rutReceptor,
      fecha: mensajeTemporal.fecha,
      editado: mensajeTemporal.editado,
      eliminado: mensajeTemporal.eliminado
    };

    // Agregar mensaje al chat completo
    const chatCompletoActualizado = [...chatPersonal.chatCompleto, mensajeParaChat];
    
    // Actualizar chat personal
    await chatPersonalRepository.update(chatPersonal.id, {
      chatCompleto: chatCompletoActualizado,
      ultimoMensaje: mensajeTemporal.contenido,
      fechaUltimoMensaje: mensajeTemporal.fecha,
      totalMensajes: chatCompletoActualizado.length,
      fechaUltimaActualizacion: new Date()
    });

    // Eliminar mensaje temporal
    await mensajeRepository.delete(mensajeTemporal.id);

    console.log(`✅ Mensaje personal procesado: ${rutEmisor} → ${rutReceptor}`);
    
    return {
      ...mensajeTemporal,
      chatId: chatPersonal.id,
      tipo: "personal"
    };

  } catch (error) {
    console.error("Error al procesar mensaje personal:", error.message);
    throw error;
  }
}

/**
 * Procesa un mensaje para chat grupal
 * @param {Object} mensajeTemporal 
 * @returns {Promise<Object>}
 */
async function procesarMensajeGrupal(mensajeTemporal) {
  try {
    const idViajeMongo = mensajeTemporal.idViajeMongo;
    const rutEmisor = mensajeTemporal.emisor.rut;
    
    // Buscar chat grupal existente (debe existir previamente)
    let chatGrupal = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    // Si no existe, significa que el viaje no tiene chat grupal establecido
    if (!chatGrupal) {
      throw new Error(`Chat grupal no encontrado para viaje ${idViajeMongo}. El chat debe crearse al establecer el viaje.`);
    }

    // Preparar mensaje para agregar al chat
    const mensajeParaChat = {
      id: mensajeTemporal.id,
      contenido: mensajeTemporal.contenido,
      emisor: rutEmisor,
      fecha: mensajeTemporal.fecha,
      editado: mensajeTemporal.editado,
      eliminado: mensajeTemporal.eliminado
    };

    // Agregar mensaje al chat completo
    const chatCompletoActualizado = [...chatGrupal.chatCompleto, mensajeParaChat];
    
    // Actualizar chat grupal
    await chatGrupalRepository.update(chatGrupal.id, {
      chatCompleto: chatCompletoActualizado,
      ultimoMensaje: mensajeTemporal.contenido,
      fechaUltimoMensaje: mensajeTemporal.fecha,
      totalMensajes: chatCompletoActualizado.length,
      fechaUltimaActualizacion: new Date()
    });

    // Eliminar mensaje temporal
    await mensajeRepository.delete(mensajeTemporal.id);

    console.log(`✅ Mensaje grupal procesado: ${rutEmisor} → viaje ${idViajeMongo}`);
    
    return {
      ...mensajeTemporal,
      chatId: chatGrupal.id,
      tipo: "grupal"
    };

  } catch (error) {
    console.error("Error al procesar mensaje grupal:", error.message);
    throw error;
  }
}

/**
 * Crea un nuevo chat personal
 * @param {string} rutEmisor 
 * @param {string} rutReceptor 
 * @param {string} identificadorChat 
 * @returns {Promise<Object>}
 */
async function crearNuevoChatPersonal(rutEmisor, rutReceptor, identificadorChat) {
  try {
    const rutMenor = rutEmisor < rutReceptor ? rutEmisor : rutReceptor;
    const rutMayor = rutEmisor < rutReceptor ? rutReceptor : rutEmisor;

    const nuevoChat = chatPersonalRepository.create({
      identificadorChat,
      rutUsuario1: rutMenor,
      rutUsuario2: rutMayor,
      chatCompleto: [],
      totalMensajes: 0
    });

    const chatGuardado = await chatPersonalRepository.save(nuevoChat);
    console.log(`📁 Nuevo chat personal creado: ${identificadorChat}`);
    
    return chatGuardado;
  } catch (error) {
    console.error("Error al crear chat personal:", error.message);
    throw error;
  }
}

/**
 * Crea identificador único para chat personal
 * @param {string} rutUsuario1 
 * @param {string} rutUsuario2 
 * @returns {string}
 */
function crearIdentificadorChat(rutUsuario1, rutUsuario2) {
  const rutMenor = rutUsuario1 < rutUsuario2 ? rutUsuario1 : rutUsuario2;
  const rutMayor = rutUsuario1 < rutUsuario2 ? rutUsuario2 : rutUsuario1;
  return `${rutMenor}-${rutMayor}`;
}

/**
 * Obtiene estadísticas del distribuidor
 * @returns {Promise<Object>}
 */
export async function obtenerEstadisticasDistribuidor() {
  try {
    const mensajesPendientes = await mensajeRepository.count();
    const chatsPersonales = await chatPersonalRepository.count();
    const chatsGrupales = await chatGrupalRepository.count();

    return {
      mensajesPendientes,
      chatsPersonales,
      chatsGrupales,
      fecha: new Date()
    };
  } catch (error) {
    console.error("Error al obtener estadísticas:", error.message);
    throw error;
  }
}

/**
 * Notifica la edición de un mensaje a través de WebSocket
 * @param {Object} mensajeEditado 
 * @param {string} tipo - "personal" o "grupal"
 */
export function notificarEdicionMensaje(mensajeEditado, tipo) {
  try {
    const mensajeParaEnviar = {
      id: mensajeEditado.id,
      contenido: mensajeEditado.contenido,
      emisor: mensajeEditado.emisor,
      receptor: mensajeEditado.receptor || null,
      idViajeMongo: mensajeEditado.idViajeMongo || null,
      fecha: mensajeEditado.fecha,
      editado: true,
      tipo
    };

    if (tipo === "personal" && mensajeEditado.receptor) {
      emitToUser(mensajeEditado.emisor, "mensaje_editado", mensajeParaEnviar);
      emitToUser(mensajeEditado.receptor, "mensaje_editado", mensajeParaEnviar);
      console.log(`📝 Notificación de edición enviada a chat personal: ${mensajeEditado.emisor} ↔ ${mensajeEditado.receptor}`);
    } else if (tipo === "grupal" && mensajeEditado.idViajeMongo) {
      emitToViaje(mensajeEditado.idViajeMongo, "mensaje_editado", mensajeParaEnviar);
      console.log(`📝 Notificación de edición enviada a chat grupal: ${mensajeEditado.idViajeMongo}`);
    }
  } catch (error) {
    console.error("Error al notificar edición de mensaje:", error.message);
  }
}

/**
 * Notifica la eliminación de un mensaje a través de WebSocket
 * @param {number} idMensaje 
 * @param {string} eliminadoPor 
 * @param {string} tipo - "personal" o "grupal"
 * @param {string|null} receptor - RUT del receptor para chats personales
 * @param {string|null} idViajeMongo - ID del viaje para chats grupales
 */
export function notificarEliminacionMensaje(idMensaje, eliminadoPor, tipo, receptor = null, idViajeMongo = null) {
  try {
    const eventoEliminacion = {
      idMensaje,
      eliminadoPor,
      fecha: new Date(),
      tipo
    };

    if (tipo === "personal" && receptor) {
      emitToUser(eliminadoPor, "mensaje_eliminado", eventoEliminacion);
      emitToUser(receptor, "mensaje_eliminado", eventoEliminacion);
      console.log(`🗑️ Notificación de eliminación enviada a chat personal: ${eliminadoPor} ↔ ${receptor}`);
    } else if (tipo === "grupal" && idViajeMongo) {
      emitToViaje(idViajeMongo, "mensaje_eliminado", eventoEliminacion);
      console.log(`🗑️ Notificación de eliminación enviada a chat grupal: ${idViajeMongo}`);
    }
  } catch (error) {
    console.error("Error al notificar eliminación de mensaje:", error.message);
  }
}
