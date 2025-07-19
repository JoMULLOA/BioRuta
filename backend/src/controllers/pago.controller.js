"use strict";
import {
  crearPreferenciaPago,
  verificarEstadoPago,
  obtenerPagosUsuario,
  procesarWebhook,
  cancelarPago,
  verificarConfiguracionMercadoPago,
} from "../services/pago.service.js";
import {
  handleErrorClient,
  handleErrorServer,
  handleSuccess,
} from "../handlers/responseHandlers.js";
import { AppDataSource } from "../config/configDb.js";

/**
 * Crear una nueva preferencia de pago
 */
export async function crearPago(req, res) {
  try {
    const { viajeId, montoTotal, descripcion, items } = req.body;
    const usuarioId = req.user.rut; // Cambiar de req.user.id a req.user.rut

    console.log("🔍 Usuario autenticado:", req.user.email, "RUT:", req.user.rut);

    if (!viajeId || !montoTotal) {
      return handleErrorClient(
        res,
        400,
        "viajeId y montoTotal son requeridos"
      );
    }

    const datosPago = {
      viajeId,
      usuarioId,
      montoTotal,
      descripcion: descripcion || `Pago de viaje #${viajeId}`,
      items,
    };

    const resultado = await crearPreferenciaPago(datosPago);

    if (!resultado.success) {
      return handleErrorServer(res, 500, resultado.message);
    }

    handleSuccess(res, 201, "Preferencia de pago creada", resultado.data);
  } catch (error) {
    console.error("Error en crearPago:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Verificar el estado de un pago
 */
export async function verificarPago(req, res) {
  try {
    const { paymentId } = req.params;

    if (!paymentId) {
      return handleErrorClient(res, 400, "paymentId es requerido");
    }

    const resultado = await verificarEstadoPago(paymentId);

    if (!resultado.success) {
      return handleErrorServer(res, 500, resultado.message);
    }

    handleSuccess(res, 200, "Estado del pago verificado", resultado.data);
  } catch (error) {
    console.error("Error en verificarPago:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Obtener todos los pagos del usuario autenticado
 */
export async function obtenerMisPagos(req, res) {
  try {
    const usuarioId = req.user.id;

    const resultado = await obtenerPagosUsuario(usuarioId);

    if (!resultado.success) {
      return handleErrorServer(res, 500, resultado.message);
    }

    handleSuccess(res, 200, "Pagos obtenidos correctamente", resultado.data);
  } catch (error) {
    console.error("Error en obtenerMisPagos:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Webhook para recibir notificaciones de MercadoPago
 */
export async function webhookMercadoPago(req, res) {
  try {
    const webhookData = req.body;

    const resultado = await procesarWebhook(webhookData);

    if (!resultado.success) {
      return handleErrorServer(res, 500, resultado.message);
    }

    res.status(200).json({ message: "OK" });
  } catch (error) {
    console.error("Error en webhookMercadoPago:", error);
    res.status(500).json({ error: "Error interno del servidor" });
  }
}

/**
 * Cancelar un pago pendiente
 */
export async function cancelarPagoController(req, res) {
  try {
    const { pagoId } = req.params;
    const usuarioId = req.user.id;

    if (!pagoId) {
      return handleErrorClient(res, 400, "pagoId es requerido");
    }

    const resultado = await cancelarPago(parseInt(pagoId), usuarioId);

    if (!resultado.success) {
      return handleErrorClient(res, 400, resultado.message);
    }

    handleSuccess(res, 200, resultado.message);
  } catch (error) {
    console.error("Error en cancelarPagoController:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Obtener el estado de un pago específico del usuario
 */
export async function obtenerEstadoPago(req, res) {
  try {
    const { pagoId } = req.params;
    const usuarioId = req.user.id;

    if (!pagoId) {
      return handleErrorClient(res, 400, "pagoId es requerido");
    }

    const pagoRepository = AppDataSource.getRepository("Pago");
    const pago = await pagoRepository.findOne({
      where: { id: parseInt(pagoId), usuarioId },
    });

    if (!pago) {
      return handleErrorClient(res, 404, "Pago no encontrado");
    }

    handleSuccess(res, 200, "Pago encontrado", pago);
  } catch (error) {
    console.error("Error en obtenerEstadoPago:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Verificar configuración de MercadoPago
 */
export async function verificarConfiguracion(req, res) {
  try {
    const resultado = await verificarConfiguracionMercadoPago();

    if (!resultado.success) {
      return handleErrorServer(res, 500, resultado.message);
    }

    handleSuccess(res, 200, resultado.message, resultado.data);
  } catch (error) {
    console.error("Error en verificarConfiguracion:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Probar la conexión con MercadoPago con una preferencia simple
 */
export async function probarConexion(req, res) {
  try {
    console.log("🧪 Probando conexión con MercadoPago...");

    // Crear una preferencia de prueba muy simple
    const datosPrueba = {
      viajeId: "test",
      usuarioId: "test",
      montoTotal: 1000,
      descripcion: "Prueba de conexión MercadoPago",
    };

    const resultado = await crearPreferenciaPago(datosPrueba);

    if (resultado.success) {
      return handleSuccess(
        res,
        200,
        "Conexión con MercadoPago exitosa",
        resultado.data
      );
    } else {
      return handleErrorServer(
        res,
        500,
        "Error en la conexión con MercadoPago",
        resultado.error
      );
    }
  } catch (error) {
    console.error("Error en probarConexion:", error);
    return handleErrorServer(res, 500, "Error al probar la conexión", error);
  }
}
