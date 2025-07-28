"use strict";
import { Router } from "express";
import {
  obtenerEstadisticasGenerales,
  obtenerDistribucionPuntuaciones,
  obtenerViajesPorMes,
  obtenerClasificacionUsuarios,
  obtenerDestinosPopulares,
  obtenerAnalisisAvanzado
} from "../controllers/estadisticas.controller.js";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";
import { isAdmin } from "../middlewares/authorization.middleware.js";

const router = Router();

// Todas las rutas requieren autenticación y permisos de administrador
router.use(authenticateJwt);
router.use(isAdmin);

// Rutas de estadísticas
router.get("/generales", obtenerEstadisticasGenerales);
router.get("/puntuaciones", obtenerDistribucionPuntuaciones);
router.get("/viajes-mes", obtenerViajesPorMes);
router.get("/clasificacion", obtenerClasificacionUsuarios);
router.get("/destinos", obtenerDestinosPopulares);
router.get("/analisis", obtenerAnalisisAvanzado);

export default router;