// src/controllers/chat.controller.js
import * as chatService from "../services/chat.service.js";

// Enviar mensaje
export async function postMensaje(req, res) {
  try {
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

// Obtener conversación entre dos usuarios
export async function getConversacion(req, res) {
  try {
    const rutUsuario1 = req.user.rut; // Accede al `rut` del usuario autenticado
    const { rutUsuario2 } = req.params;

    const mensajes = await chatService.obtenerConversacion(rutUsuario1, rutUsuario2);
    res.status(200).json(mensajes);
  } catch (error) {
    console.error("Error obteniendo conversación:", error);
    res.status(500).json({ mensaje: "Error obteniendo conversación", error });
  }
}

// Editar mensaje
export async function putMensaje(req, res) {
  try {
    const rutEmisor = req.user.rut; // Accede al `rut` del usuario autenticado
    const { idMensaje, nuevoContenido } = req.body;

    if (!idMensaje || !nuevoContenido) {
      return res.status(400).json({ mensaje: "Faltan datos para editar el mensaje." });
    }

    const mensajeEditado = await chatService.editarMensaje(idMensaje, rutEmisor, nuevoContenido);
    res.status(200).json(mensajeEditado);
  } catch (error) {
    console.error("Error editando mensaje:", error);
    res.status(500).json({ mensaje: "Error editando el mensaje", error });
  }
}

// Eliminar mensaje (soft delete)
export async function deleteMensaje(req, res) {
  try {
    const rutEmisor = req.user.rut; // Accede al `rut` del usuario autenticado
    const { idMensaje } = req.params;

    if (!idMensaje) {
      return res.status(400).json({ mensaje: "Faltan datos para eliminar el mensaje." });
    }

    const resultado = await chatService.eliminarMensaje(idMensaje, rutEmisor);
    res.status(200).json(resultado);
  } catch (error) {
    console.error("Error eliminando mensaje:", error);
    res.status(500).json({ mensaje: "Error eliminando el mensaje", error });
  }
}
