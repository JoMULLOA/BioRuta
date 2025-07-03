"use strict";
import express from "express";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";
import {
  enviarSolicitudAmistad,
  responderSolicitudAmistad,
  obtenerSolicitudesPendientes,
  obtenerAmigos,
  eliminarAmistad
} from "../controllers/amistad.controller.js";

const router = express.Router();

// Middleware para autenticar todas las rutas
router.use(authenticateJwt);

// Rutas de amistad
router.post("/solicitud", enviarSolicitudAmistad);
router.put("/solicitud/:idSolicitud", responderSolicitudAmistad);
router.get("/solicitudes-pendientes", obtenerSolicitudesPendientes);
router.get("/mis-amigos", obtenerAmigos);
router.delete("/eliminar/:rutAmigo", eliminarAmistad);

export default router;
