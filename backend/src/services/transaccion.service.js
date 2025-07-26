"use strict";
import { AppDataSource } from "../config/configDb.js";
import { updateUserService, getUserService } from "./user.service.js";

export async function crearTransaccionService({
  usuario_rut,
  tipo,
  concepto,
  monto,
  metodo_pago,
  estado = "completado",
  viaje_id = null,
  transaccion_id = null,
  datos_adicionales = null
}) {
  try {
    const transaccionRepository = AppDataSource.getRepository("Transaccion");

    const nuevaTransaccion = transaccionRepository.create({
      usuario_rut,
      tipo,
      concepto,
      monto: parseFloat(monto),
      metodo_pago,
      estado,
      viaje_id,
      transaccion_id,
      datos_adicionales,
      fecha: new Date()
    });

    const transaccionGuardada = await transaccionRepository.save(nuevaTransaccion);

    console.log(`📄 Transacción creada: ${transaccionGuardada.id} - ${tipo} por $${monto} para ${usuario_rut}`);

    return [transaccionGuardada, null];
  } catch (error) {
    console.error("Error al crear transacción:", error);
    return [null, "Error interno del servidor al crear la transacción"];
  }
}

export async function obtenerHistorialTransaccionesService(usuario_rut, limite = 50) {
  try {
    const transaccionRepository = AppDataSource.getRepository("Transaccion");

    const transacciones = await transaccionRepository.find({
      where: { usuario_rut },
      order: { fecha: "DESC" },
      take: limite
    });

    console.log(`📋 Historial obtenido para ${usuario_rut}: ${transacciones.length} transacciones`);

    return [transacciones, null];
  } catch (error) {
    console.error("Error al obtener historial de transacciones:", error);
    return [null, "Error interno del servidor al obtener el historial"];
  }
}

export async function obtenerTransaccionPorIdService(id) {
  try {
    const transaccionRepository = AppDataSource.getRepository("Transaccion");

    const transaccion = await transaccionRepository.findOne({
      where: { id },
      relations: ["usuario"]
    });

    if (!transaccion) {
      return [null, "Transacción no encontrada"];
    }

    return [transaccion, null];
  } catch (error) {
    console.error("Error al obtener transacción:", error);
    return [null, "Error interno del servidor al obtener la transacción"];
  }
}

export async function actualizarEstadoTransaccionService(id, nuevoEstado) {
  try {
    const transaccionRepository = AppDataSource.getRepository("Transaccion");

    const transaccion = await transaccionRepository.findOne({ where: { id } });

    if (!transaccion) {
      return [null, "Transacción no encontrada"];
    }

    transaccion.estado = nuevoEstado;
    transaccion.updatedAt = new Date();

    const transaccionActualizada = await transaccionRepository.save(transaccion);

    console.log(`🔄 Estado de transacción ${id} actualizado a: ${nuevoEstado}`);

    return [transaccionActualizada, null];
  } catch (error) {
    console.error("Error al actualizar estado de transacción:", error);
    return [null, "Error interno del servidor al actualizar la transacción"];
  }
}

/**
 * Actualizar saldo de usuario
 */
async function actualizarSaldoUsuario(usuarioRut, nuevoSaldo) {
  try {
    console.log(`💰 Actualizando saldo de ${usuarioRut} a $${nuevoSaldo}`);
    
    const [usuarioActualizado, error] = await updateUserService(
      { rut: usuarioRut },
      { saldo: parseFloat(nuevoSaldo) }
    );
    
    if (error) {
      console.error(`❌ Error al actualizar saldo de ${usuarioRut}: ${error}`);
      return false;
    }
    
    console.log(`✅ Saldo actualizado exitosamente para ${usuarioRut}: $${nuevoSaldo}`);
    return true;
  } catch (error) {
    console.error(`❌ Excepción al actualizar saldo de ${usuarioRut}:`, error);
    return false;
  }
}

/**
 * Actualizar límite de tarjeta de usuario
 */
async function actualizarLimiteTarjeta(usuarioRut, numeroTarjeta, nuevoLimite) {
  try {
    console.log(`💳 Actualizando límite de tarjeta ${numeroTarjeta} de ${usuarioRut} a $${nuevoLimite}`);
    
    // Obtener el usuario actual
    const [usuario, errorUsuario] = await getUserService({ rut: usuarioRut });
    if (errorUsuario || !usuario) {
      console.error(`❌ Error al obtener usuario ${usuarioRut}: ${errorUsuario}`);
      return false;
    }
    
    // Actualizar la tarjeta específica
    let tarjetas = usuario.tarjetas || [];
    const tarjetaIndex = tarjetas.findIndex(t => t.numero === numeroTarjeta);
    
    if (tarjetaIndex === -1) {
      console.error(`❌ Tarjeta ${numeroTarjeta} no encontrada para usuario ${usuarioRut}`);
      return false;
    }
    
    // Actualizar el límite de la tarjeta
    tarjetas[tarjetaIndex].limiteCredito = parseFloat(nuevoLimite);
    
    // Guardar las tarjetas actualizadas
    const [usuarioActualizado, error] = await updateUserService(
      { rut: usuarioRut },
      { tarjetas: tarjetas }
    );
    
    if (error) {
      console.error(`❌ Error al actualizar tarjetas de ${usuarioRut}: ${error}`);
      return false;
    }
    
    console.log(`✅ Límite de tarjeta actualizado exitosamente para ${usuarioRut}: $${nuevoLimite}`);
    return true;
  } catch (error) {
    console.error(`❌ Excepción al actualizar límite de tarjeta de ${usuarioRut}:`, error);
    return false;
  }
}

/**
 * Procesar pago de viaje
 */
export async function procesarPagoViaje({
  pasajeroRut,
  conductorRut,
  viajeId,
  informacionPago
}) {
  try {
    console.log(`💳 Procesando pago de viaje - Pasajero: ${pasajeroRut}, Monto: $${informacionPago.monto}`);
    
    const { metodo, monto, saldo_disponible } = informacionPago;
    
    // Obtener datos actuales de ambos usuarios
    const [pasajero, errorPasajero] = await getUserService({ rut: pasajeroRut });
    const [conductor, errorConductor] = await getUserService({ rut: conductorRut });
    
    if (errorPasajero || errorConductor) {
      throw new Error('Error al obtener datos de usuarios');
    }
    
    // Verificar el método de pago
    if (metodo === 'saldo') {
      // Usar el saldo actual del pasajero en lugar del enviado desde el frontend
      const saldoActualPasajero = parseFloat(pasajero.saldo || 0);
      
      // Verificar saldo suficiente
      if (saldoActualPasajero < monto) {
        throw new Error(`Saldo insuficiente para realizar el pago. Saldo actual: $${saldoActualPasajero}, Monto requerido: $${monto}`);
      }
      
      // Crear transacción de pago del pasajero
      const [transaccionPago, errorPago] = await crearTransaccionService({
        usuario_rut: pasajeroRut,
        tipo: 'pago',
        concepto: `Pago de viaje - ID: ${viajeId}`,
        monto: monto,
        metodo_pago: 'saldo',
        estado: 'completado',
        viaje_id: viajeId,
        transaccion_id: `viaje_${viajeId}_${Date.now()}`,
        datos_adicionales: {
          conductorRut: conductorRut,
          metodoPagoOriginal: metodo,
          saldoAnterior: saldoActualPasajero
        }
      });
      
      if (errorPago) {
        throw new Error(`Error al crear transacción de pago: ${errorPago}`);
      }
      
      // Actualizar saldo del pasajero (restar el monto)
      const nuevoSaldoPasajero = saldoActualPasajero - monto;
      const saldoPasajeroActualizado = await actualizarSaldoUsuario(pasajeroRut, nuevoSaldoPasajero);
      
      if (!saldoPasajeroActualizado) {
        console.error(`⚠️ Error al actualizar saldo del pasajero ${pasajeroRut}`);
      }
      
      // Crear transacción de cobro para el conductor
      const [transaccionCobro, errorCobro] = await crearTransaccionService({
        usuario_rut: conductorRut,
        tipo: 'cobro',
        concepto: `Cobro por viaje - ID: ${viajeId}`,
        monto: monto,
        metodo_pago: 'saldo',
        estado: 'completado',
        viaje_id: viajeId,
        transaccion_id: `viaje_cobro_${viajeId}_${Date.now()}`,
        datos_adicionales: {
          pasajeroRut: pasajeroRut,
          metodoPagoOriginal: metodo
        }
      });
      
      if (errorCobro) {
        console.warn(`⚠️ Error al crear transacción de cobro para conductor: ${errorCobro}`);
      } else {
        // Actualizar saldo del conductor (sumar el monto)
        const saldoActualConductor = parseFloat(conductor.saldo || 0);
        const nuevoSaldoConductor = saldoActualConductor + monto;
        const saldoConductorActualizado = await actualizarSaldoUsuario(conductorRut, nuevoSaldoConductor);
        
        if (!saldoConductorActualizado) {
          console.error(`⚠️ Error al actualizar saldo del conductor ${conductorRut}`);
        }
      }
      
      console.log(`✅ Pago procesado exitosamente - Transacción: ${transaccionPago.id}`);
      
      return {
        success: true,
        transaccionId: transaccionPago.id,
        message: 'Pago procesado exitosamente',
        nuevoSaldo: nuevoSaldoPasajero
      };
      
    } else if (metodo === 'tarjeta') {
      // Para pagos con tarjeta, procesarlos inmediatamente como completados
      
      // Verificar que el pasajero tenga tarjetas disponibles
      if (!informacionPago.tarjeta || !informacionPago.tarjeta.limiteCredito) {
        throw new Error('Información de tarjeta incompleta o límite de crédito no disponible');
      }
      
      const tarjetaInfo = informacionPago.tarjeta;
      const limiteDisponible = parseFloat(tarjetaInfo.limiteCredito || 0);
      
      // Verificar límite de crédito suficiente
      if (limiteDisponible < monto) {
        throw new Error(`Límite de crédito insuficiente. Límite disponible: $${limiteDisponible}, Monto requerido: $${monto}`);
      }
      
      // Crear transacción de pago del pasajero como completada
      const [transaccionPago, errorPago] = await crearTransaccionService({
        usuario_rut: pasajeroRut,
        tipo: 'pago',
        concepto: `Pago de viaje con tarjeta - ID: ${viajeId}`,
        monto: monto,
        metodo_pago: 'tarjeta',
        estado: 'completado', // Cambiar a completado inmediatamente
        viaje_id: viajeId,
        transaccion_id: `viaje_tarjeta_${viajeId}_${Date.now()}`,
        datos_adicionales: {
          conductorRut: conductorRut,
          metodoPagoOriginal: metodo,
          tarjetaUsada: {
            numero: tarjetaInfo.numero,
            tipo: tarjetaInfo.tipo,
            banco: tarjetaInfo.banco,
            limiteAnterior: limiteDisponible,
            limiteRestante: limiteDisponible - monto
          }
        }
      });
      
      if (errorPago) {
        throw new Error(`Error al crear transacción de pago con tarjeta: ${errorPago}`);
      }
      
      // Actualizar el límite de la tarjeta del pasajero
      const nuevoLimite = limiteDisponible - monto;
      const tarjetaActualizada = await actualizarLimiteTarjeta(pasajeroRut, tarjetaInfo.numero, nuevoLimite);
      
      if (!tarjetaActualizada) {
        console.warn(`⚠️ Error al actualizar límite de tarjeta del pasajero ${pasajeroRut}`);
      }
      
      // Crear transacción de cobro para el conductor como completada
      const [transaccionCobro, errorCobro] = await crearTransaccionService({
        usuario_rut: conductorRut,
        tipo: 'cobro',
        concepto: `Cobro por viaje con tarjeta - ID: ${viajeId}`,
        monto: monto,
        metodo_pago: 'tarjeta',
        estado: 'completado', // Cambiar a completado inmediatamente
        viaje_id: viajeId,
        transaccion_id: `viaje_cobro_tarjeta_${viajeId}_${Date.now()}`,
        datos_adicionales: {
          pasajeroRut: pasajeroRut,
          metodoPagoOriginal: metodo,
          tarjetaUsada: {
            numero: tarjetaInfo.numero,
            tipo: tarjetaInfo.tipo,
            banco: tarjetaInfo.banco
          }
        }
      });
      
      if (errorCobro) {
        console.warn(`⚠️ Error al crear transacción de cobro para conductor: ${errorCobro}`);
      } else {
        // Actualizar saldo del conductor (sumar el monto)
        const saldoActualConductor = parseFloat(conductor.saldo || 0);
        const nuevoSaldoConductor = saldoActualConductor + monto;
        const saldoConductorActualizado = await actualizarSaldoUsuario(conductorRut, nuevoSaldoConductor);
        
        if (!saldoConductorActualizado) {
          console.error(`⚠️ Error al actualizar saldo del conductor ${conductorRut}`);
        }
      }
      
      console.log(`✅ Pago con tarjeta procesado exitosamente - Transacción: ${transaccionPago.id}`);
      
      return {
        success: true,
        transaccionId: transaccionPago.id,
        message: 'Pago con tarjeta procesado exitosamente',
        estado: 'completado',
        nuevoLimiteTarjeta: nuevoLimite
      };
      
    } else {
      throw new Error(`Método de pago no soportado: ${metodo}`);
    }
    
  } catch (error) {
    console.error("❌ Error al procesar pago de viaje:", error);
    return {
      success: false,
      message: error.message,
      error: error.message
    };
  }
}

/**
 * Confirmar pago con tarjeta (para cuando MercadoPago confirme el pago)
 */
export async function confirmarPagoTarjeta(transaccionId, referenciaMercadoPago) {
  try {
    console.log(`💳 Confirmando pago con tarjeta - Transacción ID: ${transaccionId}`);
    
    const transaccionRepository = AppDataSource.getRepository("Transaccion");
    
    // Buscar la transacción de pago
    const transaccionPago = await transaccionRepository.findOne({
      where: { id: transaccionId, tipo: 'pago', metodo_pago: 'tarjeta', estado: 'pendiente' }
    });
    
    if (!transaccionPago) {
      throw new Error('Transacción de pago no encontrada o ya procesada');
    }
    
    const { viaje_id, monto, datos_adicionales } = transaccionPago;
    const { conductorRut, pasajeroRut } = datos_adicionales;
    
    // Actualizar estado de la transacción de pago
    await actualizarEstadoTransaccionService(transaccionId, 'completado');
    
    // Buscar y actualizar la transacción de cobro correspondiente
    const transaccionCobro = await transaccionRepository.findOne({
      where: { 
        viaje_id: viaje_id, 
        tipo: 'cobro', 
        metodo_pago: 'tarjeta', 
        estado: 'pendiente',
        usuario_rut: conductorRut || datos_adicionales.conductorRut
      }
    });
    
    if (transaccionCobro) {
      await actualizarEstadoTransaccionService(transaccionCobro.id, 'completado');
      
      // Actualizar saldo del conductor (sumar el monto)
      const [conductor, errorConductor] = await getUserService({ rut: conductorRut });
      if (!errorConductor) {
        const saldoActualConductor = parseFloat(conductor.saldo || 0);
        const nuevoSaldoConductor = saldoActualConductor + parseFloat(monto);
        await actualizarSaldoUsuario(conductorRut, nuevoSaldoConductor);
      }
    }
    
    console.log(`✅ Pago con tarjeta confirmado exitosamente - Transacción: ${transaccionId}`);
    
    return {
      success: true,
      message: 'Pago con tarjeta confirmado exitosamente',
      transaccionId: transaccionId
    };
    
  } catch (error) {
    console.error("❌ Error al confirmar pago con tarjeta:", error);
    return {
      success: false,
      message: error.message,
      error: error.message
    };
  }
}
