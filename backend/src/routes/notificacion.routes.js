"use strict";
import express from "express";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";
import {
  obtenerNotificaciones,
  contarNotificacionesPendientes
} from "../controllers/notificacion.controller.js";

const router = express.Router();

// Middleware para autenticar todas las rutas
router.use(authenticateJwt);

// Rutas de notificaciones
router.get("/", obtenerNotificaciones);
router.get("/count", contarNotificacionesPendientes);

export default router;
