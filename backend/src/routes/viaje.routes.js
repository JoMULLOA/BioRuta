"use strict";
import { Router } from "express";
import { 
  crearViaje,
  buscarViajesPorProximidad,
  obtenerViajesParaMapa,
  unirseAViaje,
  obtenerViajesUsuario
} from "../controllers/viaje.controller.js";
import { 
  viajeBodyValidation,
  busquedaProximidadValidation,
  unirseViajeValidation,
  viajesMapaValidation 
} from "../validations/viaje.validation.js";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";
import { validateBody, validateQuery } from "../middlewares/validation.middleware.js";

const router = Router();

// Crear viaje - POST /api/viajes/crear
router.post(
  "/crear", 
  authenticateJwt,
  validateBody(viajeBodyValidation),
  crearViaje
);

// Buscar viajes por proximidad - GET /api/viajes/buscar-proximidad
router.get(
  "/buscar-proximidad", 
  authenticateJwt,
  validateQuery(busquedaProximidadValidation),
  buscarViajesPorProximidad
);

// Obtener marcadores para mapa - GET /api/viajes/mapa
router.get(
  "/mapa", 
  authenticateJwt,
  validateQuery(viajesMapaValidation),
  obtenerViajesParaMapa
);

// Unirse a un viaje - POST /api/viajes/:viajeId/unirse
router.post(
  "/:viajeId/unirse", 
  authenticateJwt,
  validateBody(unirseViajeValidation),
  unirseAViaje
);

// Obtener viajes del usuario - GET /api/viajes/mis-viajes
router.get(
  "/mis-viajes", 
  authenticateJwt,
  obtenerViajesUsuario
);

export default router;
