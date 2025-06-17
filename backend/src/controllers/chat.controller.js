// src/controllers/chat.controller.js
import * as chatService from "../services/chat.service.js";

export async function postMensaje(req, res) {
  try {
    // Aquí ya puedes acceder a `req.user.rut` porque Passport lo ha inyectado.
    const rutEmisor = req.user.rut; // Accede al `rut` del usuario autenticado
    const { rutReceptor, contenido } = req.body;

    if (!rutReceptor || !contenido) {
      return res.status(400).json({ mensaje: "Faltan datos." });
    }

    const mensaje = await chatService.enviarMensaje(rutEmisor, rutReceptor, contenido);
    res.status(201).json(mensaje);
  } catch (error) {
    console.error("Error enviando mensaje:", error);
    res.status(500).json({ mensaje: "Error enviando mensaje", error });
  }
}

export async function getConversacion(req, res) {
  try {
    const rutUsuario1 = req.user.rut; // Accede al `rut` del usuario autenticado
    const { rutUsuario2 } = req.params; // Cambiar el parámetro a rutUsuario2

    // Pasamos los valores correctos para la consulta de la conversación
    const mensajes = await chatService.obtenerConversacion(rutUsuario1, rutUsuario2);

    res.status(200).json(mensajes);
  } catch (error) {
    console.error("Error obteniendo conversación:", error);
    res.status(500).json({ mensaje: "Error obteniendo conversación", error });
  }
}
