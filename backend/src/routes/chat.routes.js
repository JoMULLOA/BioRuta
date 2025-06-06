const express = require("express");
const router = express.Router();
const chatService = require("../services/chatService");

// Obtener los mensajes entre dos usuarios
router.get("/messages/:senderId/:receiverId", async (req, res) => {
  const { senderId, receiverId } = req.params;
  try {
    const messages = await chatService.getMessagesBetweenUsers(senderId, receiverId);
    res.json(messages);
  } catch (err) {
    console.error("Error al obtener los mensajes:", err);
    res.status(500).json({ error: "Error al obtener los mensajes" });
  }
});

// Enviar un mensaje
router.post("/messages", async (req, res) => {
  const { senderId, receiverId, text } = req.body;
  try {
    const message = await chatService.saveMessage({ senderId, receiverId, text });
    res.status(201).json(message);
  } catch (err) {
    console.error("Error al guardar el mensaje:", err);
    res.status(500).json({ error: "Error al guardar el mensaje" });
  }
});

module.exports = router;
