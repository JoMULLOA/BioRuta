"use strict";
import express from "express";
import {
  crearPago,
  verificarPago,
  obtenerMisPagos,
  webhookMercadoPago,
  cancelarPagoController,
  obtenerEstadoPago,
  verificarConfiguracion,
  probarConexion,
} from "../controllers/pago.controller.js";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";
import { validationMiddleware } from "../middlewares/validation.middleware.js";
import {
  crearPagoValidation,
  paymentIdValidation,
  pagoIdValidation,
} from "../validations/pago.validation.js";

const router = express.Router();

// Webhook de MercadoPago (no requiere autenticación)
router.post("/webhook", webhookMercadoPago);

// Endpoint de verificación (no requiere autenticación para testing)
router.get("/verificar-config", verificarConfiguracion);

// Endpoint de prueba de conexión (no requiere autenticación para testing)
router.post("/probar-conexion", probarConexion);

// Middleware de autenticación para todas las demás rutas
router.use(authenticateJwt);

// Rutas protegidas
router.post(
  "/crear",
  validationMiddleware(crearPagoValidation),
  crearPago
);

router.get(
  "/verificar/:paymentId",
  validationMiddleware(paymentIdValidation, "params"),
  verificarPago
);

router.get("/mis-pagos", obtenerMisPagos);

router.get(
  "/estado/:pagoId",
  validationMiddleware(pagoIdValidation, "params"),
  obtenerEstadoPago
);

router.patch(
  "/cancelar/:pagoId",
  validationMiddleware(pagoIdValidation, "params"),
  cancelarPagoController
);

export default router;
