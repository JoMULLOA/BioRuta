// src/routes/chat.route.js
import express from "express";
import { postMensaje, getConversacion } from "../controllers/chat.controller.js";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";  // Importa el middleware

const router = express.Router();

router.post("/mensaje", authenticateJwt, postMensaje);  // Aplica el middleware
router.get("/conversacion/:rutUsuario2", authenticateJwt, getConversacion);  // Aplica el middleware

export default router;
