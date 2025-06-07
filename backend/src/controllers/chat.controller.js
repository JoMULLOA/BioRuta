// src/controllers/chat.controller.js
import * as chatService from "../services/chat.service.js";

export async function postMensaje(req, res) {
  try {
    const idEmisor = req.usuario.id; // asumimos que se inyecta por middleware JWT
    const { idReceptor, contenido } = req.body;

    if (!idReceptor || !contenido) {
      return res.status(400).json({ mensaje: "Faltan datos." });
    }

    const mensaje = await chatService.enviarMensaje(idEmisor, idReceptor, contenido);
    res.status(201).json(mensaje);
  } catch (error) {
    res.status(500).json({ mensaje: "Error enviando mensaje", error });
  }
}

export async function getConversacion(req, res) {
  try {
    const idUsuario1 = req.usuario.id;
    const { idUsuario2 } = req.params;

    const mensajes = await chatService.obtenerConversacion(idUsuario1, parseInt(idUsuario2));
    res.status(200).json(mensajes);
  } catch (error) {
    res.status(500).json({ mensaje: "Error obteniendo conversación", error });
  }
}
