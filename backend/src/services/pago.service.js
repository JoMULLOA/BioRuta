"use strict";
import { MercadoPagoConfig, Preference, Payment } from 'mercadopago';
import { AppDataSource } from "../config/configDb.js";
import PagoSchema from "../entity/pago.entity.js";
import { handleErrorServer } from "../handlers/responseHandlers.js";

// Configuración de MercadoPago
console.log("🔧 Configurando MercadoPago...");
console.log("🔑 Token encontrado:", process.env.MERCADO_PAGO_ACCESS_TOKEN ? "SÍ" : "NO");
console.log("🔑 Token (primeros 20 chars):", process.env.MERCADO_PAGO_ACCESS_TOKEN ? process.env.MERCADO_PAGO_ACCESS_TOKEN.substring(0, 20) + "..." : "NO ENCONTRADO");

const client = new MercadoPagoConfig({
  accessToken: process.env.MERCADO_PAGO_ACCESS_TOKEN, // Usar el nombre correcto de la variable
  options: {
    timeout: 5000,
    idempotencyKey: 'abc'
  }
});

const preference = new Preference(client);
const payment = new Payment(client);

/**
 * Crear una preferencia de pago en MercadoPago
 * @param {Object} datosPago - Datos del pago
 * @returns {Object} - Resultado de la operación
 */
export async function crearPreferenciaPago(datosPago) {
  try {
    const { viajeId, usuarioId, montoTotal, descripcion } = datosPago;

    console.log("🔍 Datos recibidos para pago:", { viajeId, usuarioId, montoTotal, descripcion });

    // Crear preferencia simple en MercadoPago
    const preferenceData = {
      items: [
        {
          title: descripcion || "Pago de viaje en BioRuta",
          quantity: 1,
          unit_price: parseFloat(montoTotal),
          currency_id: "CLP",
        }
      ],
      external_reference: `viaje_${viajeId}_usuario_${usuarioId}`,
      statement_descriptor: "BioRuta",
    };

    console.log("📦 Datos de preferencia a enviar:", JSON.stringify(preferenceData, null, 2));

    const result = await preference.create({ body: preferenceData });

    console.log("✅ Preferencia creada exitosamente:", result.id);

    // Guardar el pago en la base de datos
    const pagoRepository = AppDataSource.getRepository("Pago");
    const nuevoPago = pagoRepository.create({
      viajeId,
      usuarioId,
      montoTotal: parseFloat(montoTotal),
      descripcion,
      mercadoPagoId: result.id,
      estado: "pendiente",
      datosRespuesta: JSON.stringify(result),
    });

    await pagoRepository.save(nuevoPago);

    return {
      success: true,
      data: {
        id: result.id,
        init_point: result.init_point,
        sandbox_init_point: result.sandbox_init_point,
        pago_id: nuevoPago.id,
      },
    };
  } catch (error) {
    console.error("❌ Error detallado en crearPreferenciaPago:");
    console.error("- Message:", error.message);
    console.error("- Status:", error.status);
    console.error("- Cause:", error.cause);
    console.error("- Error completo:", JSON.stringify(error, null, 2));
    
    return {
      success: false,
      message: "Error al crear la preferencia de pago",
      error: {
        message: error.message,
        status: error.status,
        cause: error.cause
      }
    };
  }
}

/**
 * Verificar el estado de un pago
 * @param {string} paymentId - ID del pago en MercadoPago
 * @returns {Object} - Estado del pago
 */
export async function verificarEstadoPago(paymentId) {
  try {
    const result = await payment.get({ id: paymentId });
    
    // Actualizar el estado en la base de datos
    const pagoRepository = AppDataSource.getRepository("Pago");
    const pago = await pagoRepository.findOne({
      where: { mercadoPagoId: result.preference_id }
    });

    if (pago) {
      let nuevoEstado;
      switch (result.status) {
        case "approved":
          nuevoEstado = "aprobado";
          break;
        case "rejected":
          nuevoEstado = "rechazado";
          break;
        case "cancelled":
          nuevoEstado = "cancelado";
          break;
        case "pending":
        case "in_process":
          nuevoEstado = "pendiente";
          break;
        default:
          nuevoEstado = "pendiente";
      }

      pago.estado = nuevoEstado;
      pago.metodoPago = result.payment_method_id;
      pago.datosRespuesta = JSON.stringify(result);
      
      await pagoRepository.save(pago);
    }

    return {
      success: true,
      data: {
        status: result.status,
        status_detail: result.status_detail,
        payment_method_id: result.payment_method_id,
        transaction_amount: result.transaction_amount,
      },
    };
  } catch (error) {
    console.error("Error en verificarEstadoPago:", error);
    return {
      success: false,
      message: "Error al verificar el estado del pago",
      error: error
    };
  }
}

/**
 * Obtener todos los pagos de un usuario
 * @param {number} usuarioId - ID del usuario
 * @returns {Object} - Lista de pagos
 */
export async function obtenerPagosUsuario(usuarioId) {
  try {
    const pagoRepository = AppDataSource.getRepository("Pago");
    const pagos = await pagoRepository.find({
      where: { usuarioId },
      order: { fechaCreacion: "DESC" },
    });

    return {
      success: true,
      data: pagos,
    };
  } catch (error) {
    console.error("Error en obtenerPagosUsuario:", error);
    return {
      success: false,
      message: "Error al obtener los pagos del usuario",
      error: error
    };
  }
}

/**
 * Procesar webhook de MercadoPago
 * @param {Object} webhookData - Datos del webhook
 * @returns {Object} - Resultado del procesamiento
 */
export async function procesarWebhook(webhookData) {
  try {
    const { type, data } = webhookData;

    if (type === "payment") {
      const paymentId = data.id;
      await verificarEstadoPago(paymentId);
    }

    return {
      success: true,
      message: "Webhook procesado correctamente",
    };
  } catch (error) {
    console.error("Error en procesarWebhook:", error);
    return {
      success: false,
      message: "Error al procesar el webhook",
      error: error
    };
  }
}

/**
 * Cancelar un pago
 * @param {number} pagoId - ID del pago en la base de datos
 * @param {number} usuarioId - ID del usuario
 * @returns {Object} - Resultado de la operación
 */
export async function cancelarPago(pagoId, usuarioId) {
  try {
    const pagoRepository = AppDataSource.getRepository("Pago");
    const pago = await pagoRepository.findOne({
      where: { id: pagoId, usuarioId },
    });

    if (!pago) {
      return {
        success: false,
        message: "Pago no encontrado",
      };
    }

    if (pago.estado !== "pendiente") {
      return {
        success: false,
        message: "Solo se pueden cancelar pagos pendientes",
      };
    }

    pago.estado = "cancelado";
    await pagoRepository.save(pago);

    return {
      success: true,
      message: "Pago cancelado correctamente",
    };
  } catch (error) {
    console.error("Error en cancelarPago:", error);
    return {
      success: false,
      message: "Error al cancelar el pago",
      error: error
    };
  }
}

/**
 * Verificar la configuración de MercadoPago
 * @returns {Object} - Resultado de la verificación
 */
export async function verificarConfiguracionMercadoPago() {
  try {
    console.log("Verificando token de MercadoPago:", process.env.MERCADO_PAGO_ACCESS_TOKEN ? "✓ Token encontrado" : "✗ Token no encontrado");
    
    if (!process.env.MERCADO_PAGO_ACCESS_TOKEN) {
      return {
        success: false,
        message: "Token de MercadoPago no configurado",
      };
    }

    // Crear una preferencia simple de prueba
    const testPreference = {
      items: [
        {
          title: "Test Item",
          quantity: 1,
          unit_price: 100,
          currency_id: "CLP",
        }
      ],
      external_reference: "test_" + Date.now(),
    };

    const result = await preference.create({ body: testPreference });
    
    return {
      success: true,
      message: "Configuración de MercadoPago correcta",
      data: {
        preference_id: result.id,
        token_valid: true,
      }
    };
  } catch (error) {
    console.error("Error en verificarConfiguracionMercadoPago:", error);
    return {
      success: false,
      message: "Error en la configuración de MercadoPago",
      error: error.message || error,
    };
  }
}
