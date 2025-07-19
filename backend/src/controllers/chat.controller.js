// src/controllers/chat.controller.js
import * as chatService from "../services/chat.service.js"; // Asegúrate de que esta ruta sea correcta

/**
 * POST /api/chat/mensaje
 *
 * Envía un mensaje. Este endpoint es polivalente: puede ser para un chat 1 a 1
 * o para un chat grupal de viaje.
 *
 * En el cuerpo de la solicitud (req.body), debes proporcionar:
 * - 'contenido': El texto del mensaje.
 * - Y EXCLUSIVAMENTE UNO de los siguientes:
 * - 'rutReceptor': El RUT del usuario con el que se quiere chatear 1 a 1.
 * - 'idViajeMongo': El ID de MongoDB del viaje al que pertenece el chat grupal.
 *
 * El RUT del emisor se obtiene del token JWT (req.user.rut).
 *
 * @param {object} req - Objeto de solicitud de Express.
 * @param {object} res - Objeto de respuesta de Express.
 */
export async function postMensaje(req, res) {
  try {
    const rutEmisor = req.user.rut; // Obtener el RUT del usuario autenticado desde el JWT
    const { rutReceptor, idViajeMongo, contenido } = req.body;

    // Validaciones básicas de entrada
    if (!contenido) {
      return res.status(400).json({ mensaje: "El contenido del mensaje es obligatorio." });
    }
    if (!rutReceptor && !idViajeMongo) {
      return res.status(400).json({ mensaje: "Debe especificar un 'rutReceptor' o un 'idViajeMongo'." });
    }
    if (rutReceptor && idViajeMongo) {
      return res.status(400).json({ mensaje: "No se puede especificar 'rutReceptor' e 'idViajeMongo' a la vez." });
    }

    // Llamar al servicio que maneja la lógica de envío
    const mensaje = await chatService.enviarMensaje(
      rutEmisor,
      contenido,
      rutReceptor,
      idViajeMongo
    );
    res.status(201).json(mensaje); // 201 Created
  } catch (error) {
    console.error("Error en postMensaje:", error.message);
    // Manejar errores internos del servidor o errores de validación del servicio
    res.status(500).json({ mensaje: error.message || "Error interno del servidor al enviar mensaje." });
  }
}

/**
 * GET /api/chat/conversacion/:rutUsuario2
 *
 * Obtiene todos los mensajes de una conversación 1 a 1 entre el usuario autenticado
 * (cuyo RUT se obtiene del JWT) y otro usuario especificado por su RUT en los parámetros.
 *
 * @param {object} req - Objeto de solicitud de Express (req.user.rut, req.params.rutUsuario2).
 * @param {object} res - Objeto de respuesta de Express.
 */
export async function getConversacion(req, res) {
  try {
    const rutUsuario1 = req.user.rut; // RUT del usuario autenticado
    const { rutUsuario2 } = req.params; // RUT del otro usuario en la conversación

    if (!rutUsuario2) {
      return res.status(400).json({ mensaje: "Falta el RUT del segundo usuario para la conversación." });
    }

    const mensajes = await chatService.obtenerConversacion(rutUsuario1, rutUsuario2);
    res.status(200).json(mensajes); // 200 OK
  } catch (error) {
    console.error("Error en getConversacion:", error.message);
    res.status(500).json({ mensaje: error.message || "Error interno del servidor al obtener conversación." });
  }
}

/**
 * GET /api/chat/viaje/:idViajeMongo/mensajes
 *
 * Obtiene todos los mensajes del chat grupal asociado a un viaje específico.
 * Valida que el usuario autenticado sea un participante del viaje y que el viaje esté activo.
 *
 * @param {object} req - Objeto de solicitud de Express (req.user.rut, req.params.idViajeMongo).
 * @param {object} res - Objeto de respuesta de Express.
 */
export async function getMensajesViaje(req, res) {
  try {
    const rutUsuarioSolicitante = req.user.rut; // RUT del usuario autenticado
    const { idViajeMongo } = req.params; // ID de MongoDB del viaje

    if (!idViajeMongo) {
      return res.status(400).json({ mensaje: "Falta el ID del viaje." });
    }

    const mensajes = await chatService.obtenerMensajesViaje(idViajeMongo, rutUsuarioSolicitante);
    res.status(200).json(mensajes); // 200 OK
  } catch (error) {
    console.error("Error en getMensajesViaje:", error.message);
    res.status(500).json({ mensaje: error.message || "Error interno del servidor al obtener mensajes de viaje." });
  }
}

/**
 * PUT /api/chat/mensaje
 *
 * Edita el contenido de un mensaje existente, ya sea 1 a 1 o de viaje.
 * Solo el emisor original del mensaje puede editarlo.
 *
 * En el cuerpo de la solicitud (req.body), debes proporcionar:
 * - 'idMensaje': El ID del mensaje a editar.
 * - 'nuevoContenido': El nuevo texto del mensaje.
 *
 * El RUT del emisor se obtiene del token JWT (req.user.rut).
 *
 * @param {object} req - Objeto de solicitud de Express.
 * @param {object} res - Objeto de respuesta de Express.
 */
export async function putMensaje(req, res) {
  try {
    const rutEmisor = req.user.rut; // RUT del usuario autenticado
    const { idMensaje, nuevoContenido } = req.body;

    if (!idMensaje || !nuevoContenido) {
      return res.status(400).json({ mensaje: "Faltan datos: 'idMensaje' y 'nuevoContenido' son obligatorios." });
    }

    const mensajeEditado = await chatService.editarMensaje(idMensaje, rutEmisor, nuevoContenido);
    res.status(200).json(mensajeEditado); // 200 OK
  } catch (error) {
    console.error("Error en putMensaje:", error.message);
    res.status(500).json({ mensaje: error.message || "Error interno del servidor al editar mensaje." });
  }
}

/**
 * DELETE /api/chat/mensaje/:idMensaje
 *
 * Realiza un soft delete de un mensaje (lo marca como eliminado sin borrarlo físicamente).
 * Aplica para mensajes 1 a 1 y de viaje. Solo el emisor original puede "eliminarlo".
 *
 * El ID del mensaje se obtiene de los parámetros de la URL (req.params.idMensaje).
 * El RUT del emisor se obtiene del token JWT (req.user.rut).
 *
 * @param {object} req - Objeto de solicitud de Express (req.user.rut, req.params.idMensaje).
 * @param {object} res - Objeto de respuesta de Express.
 */
export async function deleteMensaje(req, res) {
  try {
    const rutEmisor = req.user.rut; // RUT del usuario autenticado
    const { idMensaje } = req.params; // ID del mensaje a eliminar

    if (!idMensaje) {
      return res.status(400).json({ mensaje: "Falta el ID del mensaje a eliminar." });
    }

    const resultado = await chatService.eliminarMensaje(parseInt(idMensaje), rutEmisor); // Asegura que idMensaje sea un número
    res.status(200).json(resultado); // 200 OK
  } catch (error) {
    console.error("Error en deleteMensaje:", error.message);
    res.status(500).json({ mensaje: error.message || "Error interno del servidor al eliminar mensaje." });
  }
}

/**
 * GET /api/chat/buscar/conversacion/:rutUsuario2
 *
 * Busca mensajes en una conversación 1 a 1 entre el usuario autenticado y otro usuario,
 * filtrando por un término de búsqueda en el contenido del mensaje.
 *
 * @param {object} req - Objeto de solicitud de Express (req.user.rut, req.params.rutUsuario2, req.query.q).
 * @param {object} res - Objeto de respuesta de Express.
 */
export async function buscarEnConversacion(req, res) {
  try {
    const rutUsuario1 = req.user.rut;
    const { rutUsuario2 } = req.params;
    const { q } = req.query;

    if (!rutUsuario2) {
      return res.status(400).json({ mensaje: "Falta el RUT del segundo usuario." });
    }

    if (!q) {
      return res.status(400).json({ mensaje: "Falta el parámetro de búsqueda 'q'." });
    }

    const mensajes = await chatService.buscarMensajesEnConversacion(rutUsuario1, rutUsuario2, q);
    res.status(200).json(mensajes);
  } catch (error) {
    console.error("Error en buscarEnConversacion:", error.message);
    res.status(500).json({ mensaje: error.message || "Error interno del servidor al buscar mensajes." });
  }
}

/**
 * GET /api/chat/buscar/viaje/:idViajeMongo
 *
 * Busca mensajes en el chat grupal de un viaje específico,
 * filtrando por un término de búsqueda en el contenido del mensaje.
 *
 * @param {object} req - Objeto de solicitud de Express (req.user.rut, req.params.idViajeMongo, req.query.q).
 * @param {object} res - Objeto de respuesta de Express.
 */
export async function buscarEnViaje(req, res) {
  try {
    const rutUsuarioSolicitante = req.user.rut;
    const { idViajeMongo } = req.params;
    const { q } = req.query;

    if (!idViajeMongo) {
      return res.status(400).json({ mensaje: "Falta el ID del viaje." });
    }

    if (!q) {
      return res.status(400).json({ mensaje: "Falta el parámetro de búsqueda 'q'." });
    }

    const mensajes = await chatService.buscarMensajesEnViaje(idViajeMongo, rutUsuarioSolicitante, q);
    res.status(200).json(mensajes);
  } catch (error) {
    console.error("Error en buscarEnViaje:", error.message);
    res.status(500).json({ mensaje: error.message || "Error interno del servidor al buscar mensajes." });
  }
}

/**
 * GET /api/chat/usuario/chats
 *
 * Obtiene la lista de chats (1 a 1 y grupales) en los que el usuario autenticado está involucrado.
 *
 * @param {object} req - Objeto de solicitud de Express (req.user.rut).
 * @param {object} res - Objeto de respuesta de Express.
 */
export async function getChatsUsuario(req, res) {
  try {
    const rutUsuario = req.user.rut;
    const chats = await chatService.obtenerChatsUsuario(rutUsuario);
    res.status(200).json(chats);
  } catch (error) {
    console.error("Error en getChatsUsuario:", error.message);
    res.status(500).json({ mensaje: error.message || "Error interno del servidor al obtener chats." });
  }
}
