// src/routes/chat.route.js
import express from "express";
import {
  postMensaje,       // Para enviar mensajes (1 a 1 o de viaje)
  getConversacion,   // Para obtener chats 1 a 1
  getMensajesViaje,  // Para obtener chats grupales de viaje
  putMensaje,        // Para editar mensajes
  deleteMensaje,     // Para eliminar mensajes
} from "../controllers/chat.controller.js"; // Asegúrate de que esta ruta sea correcta

import { authenticateJwt } from "../middlewares/authentication.middleware.js"; // Asegúrate de que esta ruta sea correcta para tu middleware de JWT

const router = express.Router();

// --- Rutas Comunes para Operaciones de Mensajes (Enviar, Editar, Eliminar) ---
// Estas rutas son "generales" y el controlador/servicio determinará el tipo de chat
// (1 a 1 o de viaje) basándose en los datos del body/params.

/**
 * @route POST /api/chat/mensaje
 * @description Envía un nuevo mensaje (puede ser 1 a 1 o de viaje).
 * @access Private (Requiere JWT)
 * @body {string} contenido - Contenido del mensaje.
 * @body {string} [rutReceptor] - RUT del receptor para chat 1 a 1.
 * @body {string} [idViajeMongo] - ID del viaje para chat grupal.
 */
router.post("/mensaje", authenticateJwt, postMensaje);

/**
 * @route PUT /api/chat/mensaje
 * @description Edita un mensaje existente.
 * @access Private (Requiere JWT)
 * @body {number} idMensaje - ID del mensaje a editar.
 * @body {string} nuevoContenido - Nuevo contenido del mensaje.
 */
router.put("/mensaje", authenticateJwt, putMensaje);

/**
 * @route DELETE /api/chat/mensaje/:idMensaje
 * @description Realiza un soft delete de un mensaje.
 * @access Private (Requiere JWT)
 * @param {number} idMensaje - ID del mensaje a eliminar.
 */
router.delete("/mensaje/:idMensaje", authenticateJwt, deleteMensaje);


// --- Rutas Específicas para Obtener Mensajes (Lectura) ---

/**
 * @route GET /api/chat/conversacion/:rutUsuario2
 * @description Obtiene la conversación 1 a 1 entre el usuario autenticado y otro usuario.
 * @access Private (Requiere JWT)
 * @param {string} rutUsuario2 - RUT del segundo usuario en la conversación.
 */
router.get("/conversacion/:rutUsuario2", authenticateJwt, getConversacion);

/**
 * @route GET /api/chat/viaje/:idViajeMongo/mensajes
 * @description Obtiene todos los mensajes del chat grupal de un viaje específico.
 * @access Private (Requiere JWT)
 * @param {string} idViajeMongo - ID de MongoDB del viaje.
 */
router.get("/viaje/:idViajeMongo/mensajes", authenticateJwt, getMensajesViaje);


export default router;
