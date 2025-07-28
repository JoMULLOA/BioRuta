"use strict";
import { Router } from "express";
import {
  crearTransaccion,
  obtenerHistorial,
  procesarPago,
  confirmarPago,
  confirmarPagoEfectivo,
  procesarDevolucion
} from "../controllers/transaccion.controller.js";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";

const router = Router();

// Middleware de autenticación para todas las rutas
router.use(authenticateJwt);

// Crear una nueva transacción
router.post("/crear", crearTransaccion);

// Obtener historial de transacciones de un usuario
router.get("/historial/:usuario_rut", obtenerHistorial);

// Procesar pago de viaje
router.post("/procesar-pago", procesarPago);

// Confirmar pago con tarjeta (webhook de MercadoPago)
router.patch("/confirmar/:transaccionId", confirmarPago);

// Confirmar pago en efectivo (manual)
router.patch("/confirmar-efectivo/:transaccionId", confirmarPagoEfectivo);

// Procesar devolución por abandono de viaje
router.post("/procesar-devolucion", procesarDevolucion);

export default router;
