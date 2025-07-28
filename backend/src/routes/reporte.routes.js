import { Router } from "express";
import {
  crearReporte,
  obtenerTodosLosReportes,
  actualizarEstadoReporte,
  obtenerEstadisticasReportes,
  obtenerReportesUsuario,
} from "../controllers/reporte.controller.js";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";
import { isAdmin } from "../middlewares/authorization.middleware.js";

const router = Router();

// Rutas para usuarios normales
router.post("/", authenticateJwt, crearReporte);

// Rutas para administradores
router.get("/", authenticateJwt, isAdmin, obtenerTodosLosReportes);
router.put("/:id", authenticateJwt, isAdmin, actualizarEstadoReporte);
router.get("/estadisticas", authenticateJwt, isAdmin, obtenerEstadisticasReportes);
router.get("/usuario/:rutUsuario", authenticateJwt, isAdmin, obtenerReportesUsuario);

export default router;
