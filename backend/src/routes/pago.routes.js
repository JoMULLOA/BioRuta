"use strict";
import express from "express";
import {
  crearPagoController,
  verificarPagoController,
  obtenerMisPagosController,
  actualizarEstadoPagoController,
  obtenerPagosPorViajeController,
} from "../controllers/pago.controller.js";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";

const router = express.Router();

// Crear un nuevo pago
router.post(
  "/crear",
  authenticateJwt,
  crearPagoController
);

// Verificar estado de un pago específico
router.get(
  "/:paymentId",
  authenticateJwt,
  verificarPagoController
);

// Actualizar estado de un pago manualmente
router.put(
  "/:paymentId/estado",
  authenticateJwt,
  actualizarEstadoPagoController
);

// Obtener mis pagos del usuario autenticado
router.get(
  "/",
  authenticateJwt,
  obtenerMisPagosController
);

// Obtener todos los pagos de un viaje (para el conductor)
router.get(
  "/viaje/:viajeId",
  authenticateJwt,
  obtenerPagosPorViajeController
);

export default router;
