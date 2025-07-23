"use strict";
import { Router } from "express";
import { 
  crearViaje, 
  buscarViajesPorProximidad, 
  obtenerViajesParaMapa,
  unirseAViaje,
  unirseAViajeConPago,
  obtenerViajesUsuario,
  cancelarViaje,
  eliminarViaje,
  confirmarPasajero,
  cambiarEstadoViaje,
  abandonarViaje,
  obtenerViajesEnRadio,
  eliminarPasajero
} from "../controllers/viaje.controller.js";
import { 
  viajeBodyValidation,
  busquedaProximidadValidation,
  unirseViajeValidation,
  unirseViajeConPagoValidation,
  viajesMapaValidation,
  viajesRadarValidation
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

// Buscar viajes por proximidad - GET /api/viajes/buscar
router.get(
  "/buscar", 
  authenticateJwt, // Agregar autenticación para acceder al género del usuario
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

// Unirse a un viaje con pago - POST /api/viajes/:viajeId/unirse-con-pago
router.post(
  "/:viajeId/unirse-con-pago", 
  authenticateJwt,
  validateBody(unirseViajeConPagoValidation),
  unirseAViajeConPago
);

// Obtener viajes del usuario - GET /api/viajes/mis-viajes
router.get(
  "/mis-viajes", 
  authenticateJwt,
  obtenerViajesUsuario
);

// Confirmar pasajero - PUT /api/viajes/:viajeId/confirmar/:usuarioRut
router.put(
  "/:viajeId/confirmar/:usuarioRut",
  authenticateJwt,
  confirmarPasajero
);

// Eliminar pasajero - DELETE /api/viajes/:viajeId/eliminar-pasajero/:usuarioRut
router.delete(
  "/:viajeId/eliminar-pasajero/:usuarioRut",
  authenticateJwt,
  eliminarPasajero
);

// Cambiar estado del viaje - PUT /api/viajes/:viajeId/estado
router.put(
  "/:viajeId/estado",
  authenticateJwt,
  cambiarEstadoViaje
);

// Abandonar viaje (pasajero) - POST /api/viajes/:viajeId/abandonar
router.post(
  "/:viajeId/abandonar",
  authenticateJwt,
  abandonarViaje
);

router.delete("/:viajeId/eliminar", authenticateJwt, eliminarViaje);

// Buscar viajes en radio (radar) - POST /api/viajes/radar
router.post(
  "/radar",
  authenticateJwt,
  validateBody(viajesRadarValidation),
  obtenerViajesEnRadio
);

export default router;
