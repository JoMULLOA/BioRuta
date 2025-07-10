// src/services/chatDistribuidor.service.js
import { AppDataSource } from "../config/configDb.js";
import Mensaje from "../entity/mensaje.entity.js";
import ChatPersonal from "../entity/chatPersonal.entity.js";
import ChatGrupal from "../entity/chatGrupal.entity.js";
import User from "../entity/user.entity.js";

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
    
    // Buscar o crear chat grupal
    let chatGrupal = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    if (!chatGrupal) {
      throw new Error("Chat grupal no encontrado. Debe crearse cuando se inicia el viaje.");
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
 * Crea un nuevo chat grupal para un viaje
 * @param {string} idViajeMongo 
 * @param {string} rutConductor 
 * @param {Array} participantes 
 * @returns {Promise<Object>}
 */
export async function crearChatGrupal(idViajeMongo, rutConductor, participantes = []) {
  try {
    const nuevoChat = chatGrupalRepository.create({
      idViajeMongo,
      rutConductor,
      participantes,
      chatCompleto: [],
      totalMensajes: 0,
      estadoChat: "activo"
    });

    const chatGuardado = await chatGrupalRepository.save(nuevoChat);
    console.log(`📁 Nuevo chat grupal creado para viaje: ${idViajeMongo}`);
    
    return chatGuardado;
  } catch (error) {
    console.error("Error al crear chat grupal:", error.message);
    throw error;
  }
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
