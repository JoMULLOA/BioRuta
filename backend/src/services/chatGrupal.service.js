// src/services/chatGrupal.service.js
import { AppDataSource } from "../config/configDb.js";
import ChatGrupal from "../entity/chatGrupal.entity.js";
import Viaje from "../entity/viaje.entity.js";
import mongoose from "mongoose";

const chatGrupalRepository = AppDataSource.getRepository(ChatGrupal);

/**
 * Crea un chat grupal para un viaje específico
 * @param {string} idViajeMongo - ID del viaje en MongoDB
 * @param {string} rutConductor - RUT del conductor del viaje
 * @returns {Promise<Object>} Chat grupal creado
 */
export async function crearChatGrupal(idViajeMongo, rutConductor) {
  try {
    // Validar que el ID de viaje sea válido
    if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
      throw new Error("El ID de viaje proporcionado no es un ObjectId válido.");
    }

    // Verificar que el viaje existe y está activo
    const viaje = await Viaje.findById(idViajeMongo);
    if (!viaje) {
      throw new Error("El viaje no existe.");
    }

    if (viaje.estado !== "activo" && viaje.estado !== "en_curso") {
      throw new Error("El viaje no está activo para crear un chat grupal.");
    }

    // Verificar que no existe ya un chat grupal para este viaje
    const chatExistente = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    if (chatExistente) {
      console.log(`⚠️ Chat grupal ya existe para viaje: ${idViajeMongo}`);
      return chatExistente;
    }

    // Crear participantes iniciales (solo el conductor)
    const participantesIniciales = [rutConductor];

    // Crear nuevo chat grupal
    const nuevoChat = chatGrupalRepository.create({
      idViajeMongo,
      rutConductor,
      participantes: participantesIniciales,
      chatCompleto: [],
      ultimoMensaje: null,
      fechaUltimoMensaje: null,
      totalMensajes: 0,
      estadoChat: "activo",
      fechaCreacion: new Date(),
      fechaUltimaActualizacion: new Date(),
      eliminado: false
    });

    const chatGuardado = await chatGrupalRepository.save(nuevoChat);
    console.log(`✅ Chat grupal creado para viaje: ${idViajeMongo}`);
    
    return chatGuardado;
  } catch (error) {
    console.error("Error al crear chat grupal:", error.message);
    throw new Error(`Error al crear chat grupal: ${error.message}`);
  }
}

/**
 * Agrega un participante al chat grupal de un viaje
 * @param {string} idViajeMongo - ID del viaje en MongoDB
 * @param {string} rutParticipante - RUT del participante a agregar
 * @returns {Promise<Object>} Chat grupal actualizado
 */
export async function agregarParticipante(idViajeMongo, rutParticipante) {
  try {
    console.log(`🔍 INICIANDO AGREGAR PARTICIPANTE: RUT=${rutParticipante} al viaje=${idViajeMongo}`);
    
    // Validar que el ID de viaje sea válido
    if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
      console.error(`❌ ID de viaje inválido: ${idViajeMongo}`);
      throw new Error("El ID de viaje proporcionado no es un ObjectId válido.");
    }

    // Buscar el chat grupal
    console.log(`🔍 Buscando chat grupal para viaje: ${idViajeMongo}`);
    const chatGrupal = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    if (!chatGrupal) {
      console.error(`❌ Chat grupal NO ENCONTRADO para viaje: ${idViajeMongo}`);
      throw new Error("Chat grupal no encontrado para este viaje.");
    }

    console.log(`✅ Chat grupal encontrado (ID: ${chatGrupal.id}) con ${chatGrupal.participantes.length} participantes actuales`);

    // Verificar que el participante no esté ya en la lista
    if (chatGrupal.participantes.includes(rutParticipante)) {
      console.log(`⚠️ Participante ${rutParticipante} ya está en el chat grupal del viaje ${idViajeMongo}`);
      return chatGrupal;
    }

    // Agregar participante
    const nuevosParticipantes = [...chatGrupal.participantes, rutParticipante];
    console.log(`🔄 Agregando participante. Participantes antes: [${chatGrupal.participantes.join(', ')}]`);
    console.log(`🔄 Participantes después: [${nuevosParticipantes.join(', ')}]`);

    // Actualizar chat grupal
    console.log(`💾 Guardando cambios en la base de datos...`);
    await chatGrupalRepository.update(chatGrupal.id, {
      participantes: nuevosParticipantes,
      fechaUltimaActualizacion: new Date()
    });

    const chatActualizado = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    console.log(`✅ ÉXITO: Participante ${rutParticipante} agregado al chat grupal del viaje ${idViajeMongo}`);
    console.log(`📊 Total de participantes ahora: ${chatActualizado.participantes.length}`);
    
    return chatActualizado;
  } catch (error) {
    console.error("Error al agregar participante:", error.message);
    throw new Error(`Error al agregar participante: ${error.message}`);
  }
}

/**
 * Elimina un participante del chat grupal de un viaje
 * @param {string} idViajeMongo - ID del viaje en MongoDB
 * @param {string} rutParticipante - RUT del participante a eliminar
 * @returns {Promise<Object>} Chat grupal actualizado
 */
export async function eliminarParticipante(idViajeMongo, rutParticipante) {
  try {
    // Validar que el ID de viaje sea válido
    if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
      throw new Error("El ID de viaje proporcionado no es un ObjectId válido.");
    }

    // Buscar el chat grupal
    const chatGrupal = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    if (!chatGrupal) {
      throw new Error("Chat grupal no encontrado para este viaje.");
    }

    // Verificar que el participante esté en la lista
    if (!chatGrupal.participantes.includes(rutParticipante)) {
      console.log(`⚠️ Participante ${rutParticipante} no está en el chat grupal del viaje ${idViajeMongo}`);
      return chatGrupal;
    }

    // No permitir eliminar al conductor
    if (rutParticipante === chatGrupal.rutConductor) {
      throw new Error("No se puede eliminar al conductor del chat grupal.");
    }

    // Eliminar participante
    const nuevosParticipantes = chatGrupal.participantes.filter(rut => rut !== rutParticipante);

    // Actualizar chat grupal
    await chatGrupalRepository.update(chatGrupal.id, {
      participantes: nuevosParticipantes,
      fechaUltimaActualizacion: new Date()
    });

    const chatActualizado = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    console.log(`✅ Participante ${rutParticipante} eliminado del chat grupal del viaje ${idViajeMongo}`);
    
    return chatActualizado;
  } catch (error) {
    console.error("Error al eliminar participante:", error.message);
    throw new Error(`Error al eliminar participante: ${error.message}`);
  }
}

/**
 * Obtiene la lista de participantes de un chat grupal
 * @param {string} idViajeMongo - ID del viaje en MongoDB
 * @returns {Promise<Array>} Lista de RUTs de participantes
 */
export async function obtenerParticipantes(idViajeMongo) {
  try {
    // Validar que el ID de viaje sea válido
    if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
      throw new Error("El ID de viaje proporcionado no es un ObjectId válido.");
    }

    // Buscar el chat grupal
    const chatGrupal = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    if (!chatGrupal) {
      return []; // Si no hay chat grupal, no hay participantes
    }

    return chatGrupal.participantes || [];
  } catch (error) {
    console.error("Error al obtener participantes:", error.message);
    throw new Error(`Error al obtener participantes: ${error.message}`);
  }
}

/**
 * Actualiza la lista completa de participantes de un chat grupal
 * @param {string} idViajeMongo - ID del viaje en MongoDB
 * @param {Array} nuevosParticipantes - Array de RUTs de los nuevos participantes
 * @returns {Promise<Object>} Chat grupal actualizado
 */
export async function actualizarParticipantes(idViajeMongo, nuevosParticipantes) {
  try {
    // Validar que el ID de viaje sea válido
    if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
      throw new Error("El ID de viaje proporcionado no es un ObjectId válido.");
    }

    // Validar que nuevosParticipantes sea un array
    if (!Array.isArray(nuevosParticipantes)) {
      throw new Error("Los participantes deben ser un array de RUTs.");
    }

    // Buscar el chat grupal
    const chatGrupal = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    if (!chatGrupal) {
      throw new Error("Chat grupal no encontrado para este viaje.");
    }

    // Asegurar que el conductor esté siempre en la lista
    const participantesConConductor = nuevosParticipantes.includes(chatGrupal.rutConductor) 
      ? nuevosParticipantes 
      : [chatGrupal.rutConductor, ...nuevosParticipantes];

    // Actualizar chat grupal
    await chatGrupalRepository.update(chatGrupal.id, {
      participantes: participantesConConductor,
      fechaUltimaActualizacion: new Date()
    });

    const chatActualizado = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    console.log(`✅ Participantes actualizados para chat grupal del viaje ${idViajeMongo}`);
    
    return chatActualizado;
  } catch (error) {
    console.error("Error al actualizar participantes:", error.message);
    throw new Error(`Error al actualizar participantes: ${error.message}`);
  }
}

/**
 * Finaliza un chat grupal (cambia estado a finalizado)
 * @param {string} idViajeMongo - ID del viaje en MongoDB
 * @returns {Promise<Object>} Chat grupal finalizado
 */
export async function finalizarChatGrupal(idViajeMongo) {
  try {
    // Validar que el ID de viaje sea válido
    if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
      throw new Error("El ID de viaje proporcionado no es un ObjectId válido.");
    }

    // Buscar el chat grupal
    const chatGrupal = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    if (!chatGrupal) {
      console.log(`⚠️ No se encontró chat grupal para finalizar del viaje ${idViajeMongo}`);
      return null;
    }

    // Actualizar estado a finalizado
    await chatGrupalRepository.update(chatGrupal.id, {
      estadoChat: "finalizado",
      fechaUltimaActualizacion: new Date()
    });

    const chatFinalizado = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    console.log(`✅ Chat grupal finalizado para viaje ${idViajeMongo}`);
    
    return chatFinalizado;
  } catch (error) {
    console.error("Error al finalizar chat grupal:", error.message);
    throw new Error(`Error al finalizar chat grupal: ${error.message}`);
  }
}

/**
 * Verifica si un usuario es participante de un chat grupal
 * @param {string} idViajeMongo - ID del viaje en MongoDB
 * @param {string} rutUsuario - RUT del usuario a verificar
 * @returns {Promise<boolean>} True si es participante, false si no
 */
export async function esParticipante(idViajeMongo, rutUsuario) {
  try {
    const participantes = await obtenerParticipantes(idViajeMongo);
    return participantes.includes(rutUsuario);
  } catch (error) {
    console.error("Error al verificar participante:", error.message);
    return false;
  }
}

/**
 * Obtiene información completa del chat grupal
 * @param {string} idViajeMongo - ID del viaje en MongoDB
 * @returns {Promise<Object|null>} Chat grupal completo o null si no existe
 */
export async function obtenerChatGrupal(idViajeMongo) {
  try {
    // Validar que el ID de viaje sea válido
    if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
      throw new Error("El ID de viaje proporcionado no es un ObjectId válido.");
    }

    const chatGrupal = await chatGrupalRepository.findOne({
      where: { idViajeMongo }
    });

    return chatGrupal;
  } catch (error) {
    console.error("Error al obtener chat grupal:", error.message);
    throw new Error(`Error al obtener chat grupal: ${error.message}`);
  }
}

/**
 * Alias para eliminarParticipante - remover participante del chat grupal
 * @param {string} idViajeMongo - ID del viaje en MongoDB
 * @param {string} rutParticipante - RUT del participante a remover
 * @returns {Promise<Object>} Chat grupal actualizado
 */
export async function removerParticipante(idViajeMongo, rutParticipante) {
  return await eliminarParticipante(idViajeMongo, rutParticipante);
}
