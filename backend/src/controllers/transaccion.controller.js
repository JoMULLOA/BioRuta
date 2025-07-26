"use strict";
import { 
  crearTransaccionService, 
  obtenerHistorialTransaccionesService,
  procesarPagoViaje,
  confirmarPagoTarjeta 
} from "../services/transaccion.service.js";
import { 
  handleErrorClient, 
  handleErrorServer, 
  handleSuccess 
} from "../handlers/responseHandlers.js";

/**
 * Controlador para crear una nueva transacción
 */
export async function crearTransaccion(req, res) {
  try {
    const {
      usuario_rut,
      tipo,
      concepto,
      monto,
      metodo_pago,
      estado,
      viaje_id,
      transaccion_id,
      datos_adicionales
    } = req.body;

    // Validaciones básicas
    if (!usuario_rut || !tipo || !concepto || !monto || !metodo_pago) {
      return handleErrorClient(res, 400, "Faltan campos obligatorios");
    }

    const [transaccion, error] = await crearTransaccionService({
      usuario_rut,
      tipo,
      concepto,
      monto,
      metodo_pago,
      estado,
      viaje_id,
      transaccion_id,
      datos_adicionales
    });

    if (error) {
      return handleErrorServer(res, 500, error);
    }

    handleSuccess(res, 201, "Transacción creada exitosamente", transaccion);
  } catch (error) {
    console.error("Error en crearTransaccion:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Controlador para obtener el historial de transacciones de un usuario
 */
export async function obtenerHistorial(req, res) {
  try {
    const { usuario_rut } = req.params;
    const { limite } = req.query;

    if (!usuario_rut) {
      return handleErrorClient(res, 400, "RUT de usuario requerido");
    }

    const [historial, error] = await obtenerHistorialTransaccionesService(
      usuario_rut, 
      limite ? parseInt(limite) : 50
    );

    if (error) {
      return handleErrorServer(res, 500, error);
    }

    handleSuccess(res, 200, "Historial obtenido exitosamente", historial);
  } catch (error) {
    console.error("Error en obtenerHistorial:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Controlador para procesar pago de viaje
 */
export async function procesarPago(req, res) {
  try {
    const {
      pasajeroRut,
      conductorRut,
      viajeId,
      informacionPago
    } = req.body;

    // Validaciones básicas
    if (!pasajeroRut || !conductorRut || !viajeId || !informacionPago) {
      return handleErrorClient(res, 400, "Faltan campos obligatorios para procesar el pago");
    }

    if (!informacionPago.metodo || !informacionPago.monto) {
      return handleErrorClient(res, 400, "Información de pago incompleta");
    }

    const resultado = await procesarPagoViaje({
      pasajeroRut,
      conductorRut,
      viajeId,
      informacionPago
    });

    if (!resultado.success) {
      return handleErrorClient(res, 400, resultado.message);
    }

    handleSuccess(res, 200, resultado.message, {
      transaccionId: resultado.transaccionId,
      nuevoSaldo: resultado.nuevoSaldo,
      estado: resultado.estado
    });
  } catch (error) {
    console.error("Error en procesarPago:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Controlador para confirmar pago con tarjeta
 */
export async function confirmarPago(req, res) {
  try {
    const { transaccionId } = req.params;
    const { referenciaMercadoPago } = req.body;

    if (!transaccionId) {
      return handleErrorClient(res, 400, "ID de transacción requerido");
    }

    const resultado = await confirmarPagoTarjeta(transaccionId, referenciaMercadoPago);

    if (!resultado.success) {
      return handleErrorClient(res, 400, resultado.message);
    }

    handleSuccess(res, 200, resultado.message, {
      transaccionId: resultado.transaccionId
    });
  } catch (error) {
    console.error("Error en confirmarPago:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}
