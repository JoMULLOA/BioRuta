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
  eliminarPasajero,
  obtenerPrecioSugerido,
  ejecutarValidacionesAutomaticas
} from "../controllers/viaje.controller.js";
import ViajeMonitoringService from "../services/viaje.monitoring.service.js";
import { 
  viajeBodyValidation,
  busquedaProximidadValidation,
  unirseViajeValidation,
  unirseViajeConPagoValidation,
  viajesMapaValidation,
  viajesRadarValidation,
  iniciarViajeValidation,
  validarConflictoHorarioValidation,
  cambioEstadoAutomaticoValidation
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

// Obtener precio sugerido basado en ruta - POST /api/viajes/precio-sugerido
router.post(
  "/precio-sugerido",
  authenticateJwt,
  obtenerPrecioSugerido
);


// Ejecutar validaciones automáticas - GET /api/viajes/validaciones-automaticas
// Ruta para ejecutar manualmente las validaciones (admin/debug)
router.get(
  "/validaciones-automaticas",
  authenticateJwt,
  ejecutarValidacionesAutomaticas
);

// Monitoreo automático - Estado del servicio - GET /api/viajes/monitoring/status
router.get(
  "/monitoring/status",
  authenticateJwt,
  (req, res) => {
    try {
      const status = ViajeMonitoringService.getStatus();
      res.json({
        success: true,
        data: status
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: "Error obteniendo estado del monitoreo",
        error: error.message
      });
    }
  }
);

// Monitoreo automático - Ejecutar manualmente - POST /api/viajes/monitoring/execute
router.post(
  "/monitoring/execute",
  authenticateJwt,
  async (req, res) => {
    try {
      const resultado = await ViajeMonitoringService.executeNow();
      res.json({
        success: true,
        message: "Procesamiento manual ejecutado exitosamente",
        data: resultado
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: "Error ejecutando procesamiento manual",
        error: error.message
      });
    }
  }
);

export default router;
