"use strict";

import {
  crearPago,
  verificarEstadoPago,
  actualizarEstadoPago,
  obtenerHistorialPagos,
  obtenerPagosPorViaje,
  procesarPagoBasico
} from "../services/pago.service.js";
// import PagoSandboxService from "../services/pago.sandbox.service.js";
import { handleErrorClient, handleErrorServer, handleSuccess } from "../handlers/responseHandlers.js";

/**
 * Crear un nuevo pago
 */
export async function crearPagoController(req, res) {
  try {
    const { viajeId, montoTotal, descripcion } = req.body;
    const usuarioId = req.user.id;

    // Validaciones básicas
    if (!viajeId || !montoTotal) {
      return handleErrorClient(res, 400, "viajeId y montoTotal son requeridos");
    }

    const result = await crearPago({
      viajeId,
      usuarioId,
      montoTotal: parseFloat(montoTotal),
      descripcion: descripcion || `Pago por viaje ${viajeId}`
    });

    if (result.success) {
      return handleSuccess(res, 201, "Pago creado exitosamente", result.data);
    } else {
      return handleErrorServer(res, 400, result.message);
    }

  } catch (error) {
    console.error("Error en crearPagoController:", error);
    return handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Procesar un pago básico
 */
export async function procesarPagoBasicoController(req, res) {
  try {
    const { viajeId, montoTotal, descripcion } = req.body;
    const usuarioId = req.user.id;

    // Validaciones básicas
    if (!viajeId || !montoTotal) {
      return handleErrorClient(res, 400, "viajeId y montoTotal son requeridos");
    }

    const result = await procesarPagoBasico({
      viajeId,
      usuarioId,
      montoTotal: parseFloat(montoTotal),
      descripcion: descripcion || `Pago por viaje ${viajeId}`
    });

    if (result.success) {
      return handleSuccess(res, 200, "Pago procesado exitosamente", result.data);
    } else {
      return handleErrorServer(res, 400, result.message);
    }

  } catch (error) {
    console.error("Error en procesarPagoBasicoController:", error);
    return handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Verificar el estado de un pago
 */
export async function verificarPagoController(req, res) {
  try {
    const { pagoId } = req.params;

    if (!pagoId) {
      return handleErrorClient(res, 400, "pagoId es requerido");
    }

    const result = await verificarEstadoPago(pagoId);

    if (result.success) {
      return handleSuccess(res, 200, "Estado obtenido exitosamente", result.data);
    } else {
      return handleErrorServer(res, 404, result.message);
    }

  } catch (error) {
    console.error("Error en verificarPagoController:", error);
    return handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Actualizar el estado de un pago
 */
export async function actualizarEstadoPagoController(req, res) {
  try {
    const { pagoId } = req.params;
    const { estado } = req.body;

    if (!pagoId || !estado) {
      return handleErrorClient(res, 400, "pagoId y estado son requeridos");
    }

    const result = await actualizarEstadoPago(pagoId, estado);

    if (result.success) {
      return handleSuccess(res, 200, "Estado actualizado exitosamente", result.data);
    } else {
      return handleErrorServer(res, 400, result.message);
    }

  } catch (error) {
    console.error("Error en actualizarEstadoPagoController:", error);
    return handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Obtener historial de pagos del usuario autenticado
 */
export async function obtenerMisPagosController(req, res) {
  try {
    const usuarioId = req.user.id;

    const result = await obtenerHistorialPagos(usuarioId);

    if (result.success) {
      return handleSuccess(res, 200, "Historial obtenido exitosamente", result.data);
    } else {
      return handleErrorServer(res, 400, result.message);
    }

  } catch (error) {
    console.error("Error en obtenerMisPagosController:", error);
    return handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Obtener pagos por viaje (solo para el creador del viaje)
 */
export async function obtenerPagosPorViajeController(req, res) {
  try {
    const { viajeId } = req.params;

    if (!viajeId) {
      return handleErrorClient(res, 400, "viajeId es requerido");
    }

    const result = await obtenerPagosPorViaje(viajeId);

    if (result.success) {
      return handleSuccess(res, 200, "Pagos obtenidos exitosamente", result.data);
    } else {
      return handleErrorServer(res, 400, result.message);
    }

  } catch (error) {
    console.error("Error en obtenerPagosPorViajeController:", error);
    return handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Cancelar un pago
 */
export async function cancelarPagoController(req, res) {
  try {
    const { pagoId } = req.params;

    if (!pagoId) {
      return handleErrorClient(res, 400, "pagoId es requerido");
    }

    const result = await actualizarEstadoPago(pagoId, "cancelado");

    if (result.success) {
      return handleSuccess(res, 200, "Pago cancelado exitosamente", result.data);
    } else {
      return handleErrorServer(res, 400, result.message);
    }

  } catch (error) {
    console.error("Error en cancelarPagoController:", error);
    return handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Verificar pagos pendientes (para el historial)
 */
export async function verificarPagosPendientesController(req, res) {
  try {
    const usuarioId = req.user.id;

    // Por ahora solo devolvemos éxito ya que no tenemos procesador externo
    return handleSuccess(res, 200, "Verificación completada", {
      pagosActualizados: 0,
      mensaje: "Sistema básico - no hay pagos externos que verificar"
    });

  } catch (error) {
    console.error("Error en verificarPagosPendientesController:", error);
    return handleErrorServer(res, 500, "Error interno del servidor");
  }
}

// ==================== SANDBOX CONTROLLERS COMENTADOS TEMPORALMENTE ====================
/*
// Todas las funciones del sandbox están comentadas temporalmente
// hasta resolver problemas de imports de entidades

export async function obtenerSaldoController(req, res) { ... }
export async function agregarSaldoController(req, res) { ... }
export async function obtenerTarjetasDisponiblesController(req, res) { ... }
export async function asignarTarjetaController(req, res) { ... }
export async function obtenerTarjetasUsuarioController(req, res) { ... }
export async function procesarPagoSaldoController(req, res) { ... }
export async function procesarPagoTarjetaController(req, res) { ... }
export async function removerTarjetaController(req, res) { ... }
*/
