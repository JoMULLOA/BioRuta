// src/routes/chat.routes.js
import express from "express";
import {
  postMensaje,
  getConversacion,
  getMensajesViaje,
  putMensaje,
  deleteMensaje,
  buscarEnConversacion,
  buscarEnViaje,
  getChatsUsuario,
} from "../controllers/chat.controller.js";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";

const router = express.Router();

// Enviar mensaje (1 a 1 o de viaje)
router.post("/mensaje", authenticateJwt, postMensaje);

// Editar mensaje existente
router.put("/mensaje", authenticateJwt, putMensaje);

// Eliminar mensaje
router.delete("/mensaje/:idMensaje", authenticateJwt, deleteMensaje);

// Obtener conversación 1 a 1
router.get("/conversacion/:rutUsuario2", authenticateJwt, getConversacion);

// Obtener mensajes de viaje
router.get("/viaje/:idViajeMongo/mensajes", authenticateJwt, getMensajesViaje);

// Buscar mensajes en conversación 1 a 1
router.get("/conversacion/:rutUsuario2/buscar", authenticateJwt, buscarEnConversacion);

// Buscar mensajes en viaje
router.get("/viaje/:idViajeMongo/buscar", authenticateJwt, buscarEnViaje);

// Obtener todos los chats del usuario
router.get("/mis-chats", authenticateJwt, getChatsUsuario);

export default router;
