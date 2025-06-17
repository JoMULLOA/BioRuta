import { Router } from "express";
import mongoose from "mongoose";

const router = Router();

// Ping general del servidor
router.get("/", (req, res) => {
  res.json({
    success: true,
    message: "Servidor backend funcionando correctamente",
    timestamp: new Date().toISOString(),
    status: "online"
  });
});

router.get("/ping-mongo", (req, res) => {
  const estado = mongoose.connection.readyState;
  const estados = ["🔴 Desconectado", "🟢 Conectado", "🟡 Conectando", "🔵 Desconectando"];
  res.json({
    estado,
    mensaje: estados[estado] || "Estado desconocido",
    conectado: estado === 1,
  });
});

export default router;
