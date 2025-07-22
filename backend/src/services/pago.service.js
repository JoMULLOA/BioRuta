"use strict";
import { AppDataSource } from "../config/configDb.js";
import { Not, IsNull } from 'typeorm';
import PagoSchema from "../entity/pago.entity.js";
import { handleErrorServer } from "../handlers/responseHandlers.js";

/**
 * Crear un pago básico
 * @param {Object} datosPago - Datos del pago
 * @returns {Object} - Resultado de la operación
 */
export async function crearPago(datosPago) {
  try {
    const { viajeId, usuarioId, montoTotal, descripcion } = datosPago;

    console.log("🔍 Datos recibidos para pago:", { viajeId, usuarioId, montoTotal, descripcion });

    // Crear un external_reference único que incluya timestamp para evitar duplicados
    const timestamp = Date.now();
    const externalReference = `bioruta_v${viajeId}_u${usuarioId}_${timestamp}`;

    // Guardar el pago en la base de datos
    const pagoRepository = AppDataSource.getRepository("Pago");
    const nuevoPago = pagoRepository.create({
      viajeId,
      usuarioId,
      montoTotal: parseFloat(montoTotal),
      descripcion,
      estado: "pendiente",
      fechaCreacion: new Date(),
      externalReference: externalReference,
      tipoPago: "basico"
    });

    const pagoGuardado = await pagoRepository.save(nuevoPago);
    console.log("✅ Pago básico creado:", pagoGuardado.id);

    return {
      success: true,
      message: "Pago creado correctamente",
      data: {
        id: pagoGuardado.id,
        external_reference: externalReference,
        status: "pending",
        amount: montoTotal
      }
    };

  } catch (error) {
    console.error("❌ Error al crear pago:", error);
    return {
      success: false,
      message: "Error al crear el pago: " + error.message
    };
  }
}

/**
 * Verificar el estado de un pago
 * @param {string} pagoId - ID del pago
 * @returns {Object} - Estado del pago
 */
export async function verificarEstadoPago(pagoId) {
  try {
    const pagoRepository = AppDataSource.getRepository("Pago");
    const pago = await pagoRepository.findOne({ where: { id: pagoId } });

    if (!pago) {
      return {
        success: false,
        message: "Pago no encontrado"
      };
    }

    return {
      success: true,
      data: {
        id: pago.id,
        status: pago.estado,
        amount: pago.montoTotal,
        external_reference: pago.externalReference
      }
    };

  } catch (error) {
    console.error("❌ Error al verificar pago:", error);
    return {
      success: false,
      message: "Error al verificar el pago: " + error.message
    };
  }
}

/**
 * Actualizar el estado de un pago
 * @param {string} pagoId - ID del pago
 * @param {string} nuevoEstado - Nuevo estado del pago
 * @returns {Object} - Resultado de la operación
 */
export async function actualizarEstadoPago(pagoId, nuevoEstado) {
  try {
    const pagoRepository = AppDataSource.getRepository("Pago");
    const pago = await pagoRepository.findOne({ where: { id: pagoId } });

    if (!pago) {
      return {
        success: false,
        message: "Pago no encontrado"
      };
    }

    const estadoAnterior = pago.estado;
    pago.estado = nuevoEstado;
    pago.fechaActualizacion = new Date();

    await pagoRepository.save(pago);

    console.log(`✅ Estado actualizado para pago ${pago.id}: ${estadoAnterior} → ${nuevoEstado}`);

    return {
      success: true,
      message: "Estado del pago actualizado correctamente",
      data: {
        id: pago.id,
        previous_status: estadoAnterior,
        current_status: nuevoEstado
      }
    };

  } catch (error) {
    console.error("❌ Error al actualizar estado del pago:", error);
    return {
      success: false,
      message: "Error al actualizar el estado: " + error.message
    };
  }
}

/**
 * Obtener historial de pagos de un usuario
 * @param {string} usuarioId - ID del usuario
 * @returns {Object} - Lista de pagos
 */
export async function obtenerHistorialPagos(usuarioId) {
  try {
    const pagoRepository = AppDataSource.getRepository("Pago");
    const pagos = await pagoRepository.find({
      where: { usuarioId },
      order: { fechaCreacion: "DESC" }
    });

    return {
      success: true,
      data: pagos.map(pago => ({
        id: pago.id,
        montoTotal: pago.montoTotal,
        descripcion: pago.descripcion,
        estado: pago.estado,
        fechaCreacion: pago.fechaCreacion,
        externalReference: pago.externalReference
      }))
    };

  } catch (error) {
    console.error("❌ Error al obtener historial:", error);
    return {
      success: false,
      message: "Error al obtener historial de pagos: " + error.message
    };
  }
}

/**
 * Obtener pagos por viaje
 * @param {string} viajeId - ID del viaje
 * @returns {Object} - Lista de pagos del viaje
 */
export async function obtenerPagosPorViaje(viajeId) {
  try {
    const pagoRepository = AppDataSource.getRepository("Pago");
    const pagos = await pagoRepository.find({
      where: { viajeId },
      order: { fechaCreacion: "DESC" }
    });

    return {
      success: true,
      data: pagos
    };

  } catch (error) {
    console.error("❌ Error al obtener pagos del viaje:", error);
    return {
      success: false,
      message: "Error al obtener pagos del viaje: " + error.message
    };
  }
}

/**
 * Procesar pago básico (simulación para desarrollo)
 * @param {Object} datosPago - Datos del pago
 * @returns {Object} - Resultado de la operación
 */
export async function procesarPagoBasico(datosPago) {
  try {
    // Primero crear el pago
    const resultadoCreacion = await crearPago(datosPago);
    
    if (!resultadoCreacion.success) {
      return resultadoCreacion;
    }

    const pagoId = resultadoCreacion.data.id;

    // Simular procesamiento exitoso
    const resultadoActualizacion = await actualizarEstadoPago(pagoId, "aprobado");

    if (!resultadoActualizacion.success) {
      return resultadoActualizacion;
    }

    return {
      success: true,
      message: "Pago procesado correctamente",
      data: {
        id: pagoId,
        status: "approved",
        external_reference: resultadoCreacion.data.external_reference
      }
    };

  } catch (error) {
    console.error("❌ Error al procesar pago básico:", error);
    return {
      success: false,
      message: "Error al procesar el pago: " + error.message
    };
  }
}

/**
 * Procesar pago de viaje - función centralizada
 * @param {Object} datosPago - Datos del pago
 * @returns {Object} - Resultado de la operación
 */
export async function procesarPagoViajeService(datosPago) {
  try {
    const { viajeId, pasajeroRut, conductorRut, monto, descripcion = "Pago por viaje", metodoPago = 'saldo', tarjetaInfo = null } = datosPago;

    console.log("🔄 Iniciando procesamiento de pago del viaje:", { viajeId, pasajeroRut, conductorRut, monto, metodoPago });

    // Obtener repositorios
    const userRepository = AppDataSource.getRepository("User");
    const transaccionRepository = AppDataSource.getRepository("Transaccion");

    // Buscar usuarios
    const [pasajero, conductor] = await Promise.all([
      userRepository.findOne({ where: { rut: pasajeroRut } }),
      userRepository.findOne({ where: { rut: conductorRut } })
    ]);

    if (!pasajero || !conductor) {
      console.error("❌ Usuario no encontrado:", { pasajero: !!pasajero, conductor: !!conductor });
      return { success: false, message: "Usuario no encontrado" };
    }

    console.log("👥 Usuarios encontrados:", {
      pasajero: { rut: pasajero.rut, saldo: pasajero.saldo },
      conductor: { rut: conductor.rut, saldo: conductor.saldo }
    });

    const montoNumerico = parseFloat(monto);
    const saldoPasajero = parseFloat(pasajero.saldo);
    const saldoConductor = parseFloat(conductor.saldo);

    // Validar método de pago
    if (metodoPago === 'saldo') {
      if (saldoPasajero < montoNumerico) {
        console.error("❌ Saldo insuficiente:", { saldoActual: saldoPasajero, montoRequerido: montoNumerico });
        return { success: false, message: "Saldo insuficiente" };
      }
    } else if (metodoPago === 'tarjeta') {
      // Para pagos con tarjeta, validar que hay límite de crédito disponible
      if (!tarjetaInfo) {
        console.error("❌ Información de tarjeta requerida para pago con tarjeta");
        return { success: false, message: "Información de tarjeta requerida" };
      }
      
      const limiteCredito = parseFloat(tarjetaInfo.limiteCredito || 0);
      if (limiteCredito < montoNumerico) {
        console.error("❌ Límite de crédito insuficiente:", { limiteDisponible: limiteCredito, montoRequerido: montoNumerico });
        return { success: false, message: "Límite de crédito insuficiente en la tarjeta" };
      }
      
      console.log("💳 Pago con tarjeta validado:", { 
        tarjeta: tarjetaInfo.numero.slice(-4), 
        limite: limiteCredito, 
        monto: montoNumerico 
      });
    }

    // Realizar la transacción
    await AppDataSource.transaction(async manager => {
      let nuevoSaldoPasajero = saldoPasajero;
      let nuevoSaldoConductor = saldoConductor;
      let descripcionPago = "";
      
      if (metodoPago === 'saldo') {
        // Pago con saldo: descontar del pasajero y agregar al conductor
        nuevoSaldoPasajero = saldoPasajero - montoNumerico;
        nuevoSaldoConductor = saldoConductor + montoNumerico;
        descripcionPago = "Pago desde saldo";
        
        pasajero.saldo = nuevoSaldoPasajero;
        conductor.saldo = nuevoSaldoConductor;
        
        await manager.save("User", pasajero);
        await manager.save("User", conductor);
        
        console.log("💰 Saldos actualizados (pago con saldo):", {
          pasajero: { rut: pasajero.rut, nuevoSaldo: nuevoSaldoPasajero },
          conductor: { rut: conductor.rut, nuevoSaldo: nuevoSaldoConductor }
        });
      } else if (metodoPago === 'tarjeta') {
        // Pago con tarjeta: solo agregar al conductor (no descontar del pasajero)
        nuevoSaldoConductor = saldoConductor + montoNumerico;
        descripcionPago = `Pago con tarjeta ${tarjetaInfo.tipo} terminada en ${tarjetaInfo.numero.slice(-4)}`;
        
        conductor.saldo = nuevoSaldoConductor;
        
        // Actualizar límite de crédito usado en la tarjeta
        const tarjetasUsuario = pasajero.tarjetas || [];
        const tarjetaIndex = tarjetasUsuario.findIndex(t => t.numero === tarjetaInfo.numero);
        
        if (tarjetaIndex !== -1) {
          const tarjetaActual = tarjetasUsuario[tarjetaIndex];
          const limiteActual = parseFloat(tarjetaActual.limiteCredito || 0);
          const nuevoLimite = limiteActual - montoNumerico;
          
          // Actualizar el límite de crédito de la tarjeta
          tarjetasUsuario[tarjetaIndex].limiteCredito = Math.max(0, nuevoLimite);
          pasajero.tarjetas = tarjetasUsuario;
          
          console.log(`💳 Límite de crédito actualizado: ${tarjetaInfo.numero.slice(-4)}`);
          console.log(`   Límite anterior: $${limiteActual}`);
          console.log(`   Monto descontado: $${montoNumerico}`);
          console.log(`   Nuevo límite: $${Math.max(0, nuevoLimite)}`);
          
          // Guardar el pasajero con las tarjetas actualizadas
          await manager.save("User", pasajero);
        } else {
          console.warn(`⚠️ Tarjeta ${tarjetaInfo.numero.slice(-4)} no encontrada en el perfil del usuario`);
        }
        
        await manager.save("User", conductor);
        
        console.log("💳 Saldos actualizados (pago con tarjeta):", {
          pasajero: { rut: pasajero.rut, saldo: "sin cambios" },
          conductor: { rut: conductor.rut, nuevoSaldo: nuevoSaldoConductor },
          tarjeta: tarjetaInfo.numero.slice(-4)
        });
      } else if (metodoPago === 'efectivo') {
        // Pago en efectivo: no hay cambios de saldo, solo registro
        descripcionPago = "Pago en efectivo (no afecta saldos digitales)";
        
        console.log("💵 Pago en efectivo registrado:", {
          pasajero: { rut: pasajero.rut, saldo: "sin cambios" },
          conductor: { rut: conductor.rut, saldo: "sin cambios" },
          nota: "Pago se realizará físicamente"
        });
      }

      // Crear transacciones para el historial
      const transacciones = [
        // Transacción para el pasajero (pago)
        {
          viaje_id: viajeId,
          usuario_rut: pasajeroRut,
          tipo: 'pago',
          concepto: `${descripcion} - ${descripcionPago} - Viaje ID: ${viajeId}`,
          monto: montoNumerico,
          metodo_pago: metodoPago,
          estado: 'completado',
          fecha: new Date(),
          transaccion_id: null,
          datos_adicionales: { 
            usuarioDestino: conductorRut,
            ...(metodoPago === 'tarjeta' && tarjetaInfo ? { 
              tarjeta: {
                tipo: tarjetaInfo.tipo,
                terminacion: tarjetaInfo.numero.slice(-4),
                banco: tarjetaInfo.banco,
                limiteAnterior: parseFloat(tarjetaInfo.limiteCredito || 0),
                limiteNuevo: Math.max(0, parseFloat(tarjetaInfo.limiteCredito || 0) - montoNumerico)
              }
            } : {})
          }
        },
        // Transacción para el conductor (cobro)
        {
          viaje_id: viajeId,
          usuario_rut: conductorRut,
          tipo: 'cobro',
          concepto: `${descripcion} - ${descripcionPago} - Viaje ID: ${viajeId}`,
          monto: montoNumerico,
          metodo_pago: metodoPago,
          estado: metodoPago === 'efectivo' ? 'pendiente' : 'completado', // Efectivo queda pendiente hasta confirmación física
          fecha: new Date(),
          transaccion_id: null,
          datos_adicionales: { 
            usuarioOrigen: pasajeroRut,
            ...(metodoPago === 'tarjeta' && tarjetaInfo ? { 
              tarjeta: {
                tipo: tarjetaInfo.tipo,
                terminacion: tarjetaInfo.numero.slice(-4),
                banco: tarjetaInfo.banco,
                limiteAnterior: parseFloat(tarjetaInfo.limiteCredito || 0),
                limiteNuevo: Math.max(0, parseFloat(tarjetaInfo.limiteCredito || 0) - montoNumerico)
              }
            } : {})
          }
        }
      ];

      for (const transaccionData of transacciones) {
        console.log("🔧 Creando transacción con datos:", transaccionData);
        
        const transaccionRepository = manager.getRepository("Transaccion");
        const nuevaTransaccion = transaccionRepository.create(transaccionData);
        
        console.log("🔍 Transacción creada:", nuevaTransaccion);
        
        await transaccionRepository.save(nuevaTransaccion);
        console.log("✅ Transacción guardada correctamente");
      }

      console.log("📝 Transacciones creadas en el historial para ambos usuarios");
    });

    console.log("✅ Pago procesado exitosamente");
    return {
      success: true,
      message: `Pago procesado correctamente con ${metodoPago}`,
      data: {
        viajeId,
        monto: montoNumerico,
        metodoPago,
        pasajero: {
          rut: pasajeroRut,
          nuevoSaldo: pasajero.saldo
        },
        conductor: {
          rut: conductorRut,
          nuevoSaldo: conductor.saldo
        },
        ...(metodoPago === 'tarjeta' && tarjetaInfo ? {
          tarjetaUsada: {
            tipo: tarjetaInfo.tipo,
            terminacion: tarjetaInfo.numero.slice(-4)
          }
        } : {})
      }
    };

  } catch (error) {
    console.error("❌ Error al procesar pago del viaje:", error);
    return {
      success: false,
      message: "Error interno del servidor al procesar el pago: " + error.message
    };
  }
}
