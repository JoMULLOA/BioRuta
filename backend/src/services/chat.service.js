// src/services/chat.service.js
import Mensaje from "../entity/mensaje.entity.js";
import User from "../entity/user.entity.js";
import { AppDataSource } from "../config/configDb.js"; // Asegúrate de que esta ruta sea correcta para tu configuración de TypeORM

// ¡IMPORTANTE! Ajusta esta línea para que apunte a la ubicación real de tu archivo viaje.entity.js de Mongoose.
import Viaje from "../entity/viaje.entity.js"; // <--- ¡Modifica esta línea con la ruta correcta!
import mongoose from "mongoose"; // Necesario para validar los ObjectId de MongoDB

// Repositorios de TypeORM para interactuar con PostgreSQL
const mensajeRepository = AppDataSource.getRepository(Mensaje);
const userRepository = AppDataSource.getRepository(User);

/**
 * Envía un mensaje, que puede ser para un chat 1 a 1 o para un chat de viaje.
 * Requiere que se especifique un 'rutReceptor' O un 'idViajeMongo', pero no ambos.
 *
 * @param {string} rutEmisor - El RUT del usuario que envía el mensaje.
 * @param {string} contenido - El contenido del mensaje.
 * @param {string|null} rutReceptor - El RUT del usuario receptor (solo para chat 1 a 1).
 * @param {string|null} idViajeMongo - El ObjectId de MongoDB del viaje (solo para chat grupal de viaje).
 * @returns {Promise<Mensaje>} El objeto Mensaje guardado en la base de datos.
 * @throws {Error} Si el emisor no existe, faltan parámetros, o no se cumplen las validaciones del chat de viaje.
 */
export async function enviarMensaje(rutEmisor, contenido, rutReceptor = null, idViajeMongo = null) {
  try {
    const emisor = await userRepository.findOne({ where: { rut: rutEmisor } });
    if (!emisor) {
      throw new Error("El emisor no existe.");
    }

    const nuevoMensaje = mensajeRepository.create({ contenido, emisor });

    // Lógica para determinar si es un chat 1 a 1 o de viaje
    if (rutReceptor && idViajeMongo) {
      throw new Error("No se puede especificar un receptor y un ID de viaje a la vez. Un mensaje debe ser 1 a 1 o de viaje.");
    } else if (rutReceptor) { // Es un chat 1 a 1
      const receptor = await userRepository.findOne({ where: { rut: rutReceptor } });
      if (!receptor) {
        throw new Error("El receptor no existe.");
      }
      nuevoMensaje.receptor = receptor;
      nuevoMensaje.idViajeMongo = null; // Asegurar que es null para chat 1 a 1
    } else if (idViajeMongo) { // Es un chat grupal de viaje
      if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
        throw new Error("El ID de viaje proporcionado no es un ObjectId válido.");
      }

      // Buscar el viaje en MongoDB para validaciones
      const viaje = await Viaje.findById(idViajeMongo);

      // Validar que el viaje exista y esté en un estado que permita el chat
      if (!viaje || (viaje.estado !== "activo" && viaje.estado !== "en_curso")) {
        throw new Error("El viaje no existe o no está activo/en curso para chatear.");
      }

      // Validar que el emisor sea un participante activo y confirmado del viaje
      const esConductor = viaje.usuario_rut === rutEmisor;
      const esPasajeroConfirmado = viaje.pasajeros.some(
        (p) => p.usuario_rut === rutEmisor && p.estado === 'confirmado'
      );

      if (!esConductor && !esPasajeroConfirmado) {
        throw new Error("No eres un participante confirmado de este viaje para enviar mensajes.");
      }

      nuevoMensaje.idViajeMongo = idViajeMongo; // Asignar el ID de MongoDB
      nuevoMensaje.receptor = null; // Asegurar que es null para chat de viaje
    } else {
      throw new Error("Se debe especificar un 'rutReceptor' (para chat 1 a 1) o un 'idViajeMongo' (para chat grupal de viaje).");
    }

    return await mensajeRepository.save(nuevoMensaje);
  } catch (error) {
    console.error("Error al enviar el mensaje:", error.message);
    throw new Error(`Error al enviar el mensaje: ${error.message}`);
  }
}

/**
 * Obtiene todos los mensajes de una conversación 1 a 1 entre dos usuarios.
 * Solo recupera mensajes que NO están asociados a un viaje.
 *
 * @param {string} rutUsuario1 - El RUT del primer usuario en la conversación.
 * @param {string} rutUsuario2 - El RUT del segundo usuario en la conversación.
 * @returns {Promise<Mensaje[]>} Un arreglo de objetos Mensaje ordenados por fecha.
 * @throws {Error} En caso de un error en la base de datos o en la lógica.
 */
export async function obtenerConversacion(rutUsuario1, rutUsuario2) {
  try {
    const mensajes = await mensajeRepository.find({
      where: [
        // Mensajes enviados de Usuario1 a Usuario2
        { emisor: { rut: rutUsuario1 }, receptor: { rut: rutUsuario2 }, eliminado: false, idViajeMongo: null },
        // Mensajes enviados de Usuario2 a Usuario1
        { emisor: { rut: rutUsuario2 }, receptor: { rut: rutUsuario1 }, eliminado: false, idViajeMongo: null },
      ],
      order: { fecha: "ASC" }, // Ordenar cronológicamente
      relations: ["emisor", "receptor"], // Cargar los objetos de usuario asociados
    });
    return mensajes;
  } catch (error) {
    console.error("Error al obtener la conversación 1 a 1:", error.message);
    throw new Error(`Error al obtener la conversación 1 a 1: ${error.message}`);
  }
}

/**
 * Obtiene todos los mensajes de un chat grupal de un viaje específico.
 * Valida que el viaje exista, esté activo/en curso, y que el usuario solicitante sea un participante confirmado.
 *
 * @param {string} idViajeMongo - El ObjectId de MongoDB del viaje.
 * @param {string} rutUsuarioSolicitante - El RUT del usuario que solicita ver los mensajes.
 * @returns {Promise<Mensaje[]>} Un arreglo de objetos Mensaje del chat de viaje.
 * @throws {Error} Si el ID del viaje no es válido, el viaje no existe/activo, o el usuario no tiene permisos.
 */
export async function obtenerMensajesViaje(idViajeMongo, rutUsuarioSolicitante) {
  try {
    if (!mongoose.Types.ObjectId.isValid(idViajeMongo)) {
      throw new Error("El ID de viaje proporcionado no es un ObjectId válido.");
    }

    // Buscar el viaje en MongoDB para validaciones
    const viaje = await Viaje.findById(idViajeMongo);

    // Validar existencia y estado del viaje
    if (!viaje || (viaje.estado !== "activo" && viaje.estado !== "en_curso")) {
      throw new Error("El viaje no existe o no está activo/en curso.");
    }

    // Verificar que el usuario solicitante sea un participante activo y confirmado del viaje
    const esConductor = viaje.usuario_rut === rutUsuarioSolicitante;
    const esPasajeroConfirmado = viaje.pasajeros.some(
      (p) => p.usuario_rut === rutUsuarioSolicitante && p.estado === 'confirmado'
    );

    if (!esConductor && !esPasajeroConfirmado) {
      throw new Error("No tienes permiso para ver los mensajes de este viaje.");
    }

    // Obtener los mensajes de PostgreSQL vinculados a este ID de viaje de MongoDB
    const mensajes = await mensajeRepository.find({
      where: { idViajeMongo: idViajeMongo, eliminado: false },
      order: { fecha: "ASC" },
      relations: ["emisor"], // Solo necesitamos cargar el emisor para estos mensajes
    });
    return mensajes;
  } catch (error) {
    console.error("Error al obtener los mensajes del viaje:", error.message);
    throw new Error(`Error al obtener los mensajes del viaje: ${error.message}`);
  }
}

/**
 * Edita el contenido de un mensaje existente.
 * Aplica tanto para mensajes 1 a 1 como para mensajes de chat de viaje.
 * Valida que solo el emisor original pueda editar y, si es de viaje, que el viaje esté activo.
 *
 * @param {number} idMensaje - El ID del mensaje en PostgreSQL.
 * @param {string} rutEmisor - El RUT del usuario que intenta editar (debe ser el emisor original).
 * @param {string} nuevoContenido - El nuevo contenido para el mensaje.
 * @returns {Promise<Mensaje>} El objeto Mensaje editado.
 * @throws {Error} Si el mensaje no se encuentra, el usuario no tiene permisos, o el viaje no está activo.
 */
export async function editarMensaje(idMensaje, rutEmisor, nuevoContenido) {
  try {
    const mensaje = await mensajeRepository.findOne({
      where: { id: idMensaje },
      relations: ["emisor", "receptor"], // Cargar ambas relaciones para determinar el tipo de chat
    });

    if (!mensaje) {
      throw new Error("Mensaje no encontrado.");
    }

    // Validar que solo el emisor original pueda editar
    if (mensaje.emisor.rut !== rutEmisor) {
      throw new Error("No tienes permiso para editar este mensaje.");
    }

    // Si el mensaje es de un chat de viaje, validar que el viaje esté activo
    if (mensaje.idViajeMongo) {
      if (!mongoose.Types.ObjectId.isValid(mensaje.idViajeMongo)) {
        throw new Error("El mensaje está asociado a un ID de viaje inválido.");
      }
      const viaje = await Viaje.findById(mensaje.idViajeMongo);
      if (!viaje || (viaje.estado !== "activo" && viaje.estado !== "en_curso")) {
        throw new Error("El mensaje pertenece a un viaje que no está activo/en curso y, por lo tanto, no puede ser editado.");
      }
    }
    // Si es un mensaje 1 a 1 (mensaje.receptor no es null y mensaje.idViajeMongo es null), no se necesita validación de viaje.

    mensaje.contenido = nuevoContenido;
    mensaje.editado = true;
    return await mensajeRepository.save(mensaje);
  } catch (error) {
    console.error("Error al editar el mensaje:", error.message);
    throw new Error(`Error al editar el mensaje: ${error.message}`);
  }
}

/**
 * Realiza un soft delete (marcar como eliminado) de un mensaje existente.
 * Aplica tanto para mensajes 1 a 1 como para mensajes de chat de viaje.
 * Valida que solo el emisor original pueda "eliminar" y, si es de viaje, que el viaje esté activo.
 *
 * @param {number} idMensaje - El ID del mensaje en PostgreSQL.
 * @param {string} rutEmisor - El RUT del usuario que intenta eliminar (debe ser el emisor original).
 * @returns {{mensaje: string}} Un objeto de confirmación.
 * @throws {Error} Si el mensaje no se encuentra, el usuario no tiene permisos, o el viaje no está activo.
 */
export async function eliminarMensaje(idMensaje, rutEmisor) {
  try {
    const mensaje = await mensajeRepository.findOne({
      where: { id: idMensaje },
      relations: ["emisor", "receptor"], // Cargar ambas relaciones para determinar el tipo de chat
    });

    if (!mensaje) {
      throw new Error("Mensaje no encontrado.");
    }

    // Validar que solo el emisor original pueda eliminar
    if (mensaje.emisor.rut !== rutEmisor) {
      throw new Error("No tienes permiso para eliminar este mensaje.");
    }

    // Si el mensaje es de un chat de viaje, validar que el viaje esté activo
    if (mensaje.idViajeMongo) {
      if (!mongoose.Types.ObjectId.isValid(mensaje.idViajeMongo)) {
        throw new Error("El mensaje está asociado a un ID de viaje inválido.");
      }
      const viaje = await Viaje.findById(mensaje.idViajeMongo);
      if (!viaje || (viaje.estado !== "activo" && viaje.estado !== "en_curso")) {
        throw new Error("El mensaje pertenece a un viaje que no está activo/en curso y, por lo tanto, no puede ser eliminado.");
      }
    }
    // Si es un mensaje 1 a 1, no se necesita validación de viaje.

    mensaje.eliminado = true;
    await mensajeRepository.save(mensaje);
    return { mensaje: "Mensaje eliminado exitosamente" };
  } catch (error) {
    console.error("Error al eliminar el mensaje:", error.message);
    throw new Error(`Error al eliminar el mensaje: ${error.message}`);
  }
}