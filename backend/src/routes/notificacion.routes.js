"use strict";
import express from "express";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";
import {
  obtenerNotificaciones,
  contarNotificacionesPendientes,
  marcarComoLeida,
  responderSolicitudViaje,
  abandonarViaje
} from "../controllers/notificacion.controller.js";

const router = express.Router();

// Middleware para autenticar todas las rutas
router.use(authenticateJwt);

// Rutas de notificaciones
router.get("/", obtenerNotificaciones);
router.get("/pendientes", obtenerNotificaciones); // Alias para compatibilidad con frontend
router.get("/count", contarNotificacionesPendientes);
router.patch("/:id/leer", marcarComoLeida);
router.post("/:id/responder", responderSolicitudViaje);
router.post("/viaje/:viajeId/abandonar", abandonarViaje);

export default router;
