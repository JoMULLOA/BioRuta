// src/routes/chat.route.js
import express from "express";
import { postMensaje, getConversacion, putMensaje, deleteMensaje } from "../controllers/chat.controller.js";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";  // Importa el middleware

const router = express.Router();

// Rutas para mensajes
router.post("/mensaje", authenticateJwt, postMensaje);  // Enviar mensaje
router.get("/conversacion/:rutUsuario2", authenticateJwt, getConversacion);  // Obtener conversación entre dos usuarios
router.put("/mensaje", authenticateJwt, putMensaje);  // Editar mensaje
router.delete("/mensaje/:idMensaje", authenticateJwt, deleteMensaje);  // Eliminar mensaje (soft delete)

export default router;
