

import express from "express";
import { postMensaje, getConversacion } from "../controllers/chat.controller.js";

const router = express.Router();

router.post("/mensaje", postMensaje);
router.get("/conversacion/:idUsuario2", getConversacion);

export default router;
