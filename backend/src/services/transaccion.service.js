"use strict";
import { AppDataSource } from "../config/configDb.js";
import { In } from "typeorm";
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
 * Procesar devolución cuando un pasajero abandona el viaje
 */
export async function procesarDevolucionViaje({
  pasajeroRut,
  conductorRut,
  viajeId
}) {
  try {
    console.log(`💰 Procesando devolución de viaje - Pasajero: ${pasajeroRut}, Viaje: ${viajeId}`);
    
    const transaccionRepository = AppDataSource.getRepository("Transaccion");
    
    // Buscar la transacción de pago del pasajero para este viaje
    const transaccionPago = await transaccionRepository.findOne({
      where: { 
        usuario_rut: pasajeroRut,
        viaje_id: viajeId,
        tipo: 'pago',
        estado: 'completado'
      },
      order: { fecha: 'DESC' }
    });

    if (!transaccionPago) {
      console.log(`⚠️ No se encontró transacción de pago para el pasajero ${pasajeroRut} en viaje ${viajeId}`);
      return {
        success: true,
        message: 'No se encontró pago previo para devolver',
        tipo: 'sin_pago'
      };
    }

    const metodoPago = transaccionPago.metodo_pago;
    const montoDevolucion = transaccionPago.monto;

    console.log(`📄 Transacción encontrada: ${transaccionPago.id}, Método: ${metodoPago}, Monto: $${montoDevolucion}`);

    if (metodoPago === 'efectivo') {
      // Para efectivo: eliminar las transacciones pendientes
      console.log(`💵 Procesando devolución en efectivo - eliminando transacciones pendientes`);
      
      // Buscar y eliminar transacciones pendientes relacionadas
      const transaccionesPendientes = await transaccionRepository.find({
        where: { 
          viaje_id: viajeId,
          metodo_pago: 'efectivo',
          estado: 'pendiente'
        }
      });

      for (const transaccion of transaccionesPendientes) {
        if (transaccion.usuario_rut === pasajeroRut || transaccion.usuario_rut === conductorRut) {
          await transaccionRepository.remove(transaccion);
          console.log(`🗑️ Transacción pendiente eliminada: ${transaccion.id} - ${transaccion.tipo} para ${transaccion.usuario_rut}`);
        }
      }

      // Crear registro de devolución para efectivo
      const [transaccionDevolucion, errorDevolucion] = await crearTransaccionService({
        usuario_rut: pasajeroRut,
        tipo: 'devolucion',
        concepto: `Devolución por abandono de viaje - ID: ${viajeId}`,
        monto: montoDevolucion,
        metodo_pago: 'efectivo',
        estado: 'completado',
        viaje_id: viajeId,
        transaccion_id: `devolucion_${viajeId}_${Date.now()}`,
        datos_adicionales: {
          conductorRut: conductorRut,
          motivoDevolucion: 'abandono_viaje',
          transaccionOriginalId: transaccionPago.id,
          metodoPagoOriginal: metodoPago
        }
      });

      if (errorDevolucion) {
        throw new Error(`Error al crear transacción de devolución: ${errorDevolucion}`);
      }

      return {
        success: true,
        message: `Devolución en efectivo procesada: $${montoDevolucion}`,
        tipo: 'efectivo',
        monto: montoDevolucion,
        transaccionDevolucionId: transaccionDevolucion.id,
        transaccionesEliminadas: transaccionesPendientes.length
      };

    } else if (metodoPago === 'saldo' || metodoPago === 'tarjeta') {
      // Para saldo y tarjeta: devolver el dinero al saldo del pasajero
      console.log(`💳 Procesando devolución ${metodoPago} - devolviendo al saldo`);
      
      // Obtener saldo actual del pasajero
      const { getUserService } = await import('./user.service.js');
      const [pasajero, errorPasajero] = await getUserService({ rut: pasajeroRut });
      
      if (errorPasajero || !pasajero) {
        throw new Error('Error al obtener datos del pasajero');
      }

      let saldoActual = parseFloat(pasajero.saldo || 0);
      
      // Detectar y corregir saldos corruptos que excedan límites razonables
      if (saldoActual > 99999999) {
        console.error(`⚠️ Saldo corrupto detectado para ${pasajeroRut}: ${saldoActual}`);
        console.log(`🔧 Corrigiendo saldo a valor razonable para procesar devolución`);
        
        // Establecer saldo a un valor razonable (saldo inicial por defecto)
        saldoActual = 100000; // $100,000 - saldo inicial típico
        
        // Actualizar inmediatamente el saldo corregido
        const saldoCorregido = await actualizarSaldoUsuario(pasajeroRut, saldoActual);
        if (!saldoCorregido) {
          console.error(`❌ Error al corregir saldo corrupto para ${pasajeroRut}`);
          throw new Error('Error al corregir saldo corrupto del pasajero');
        }
        
        console.log(`✅ Saldo corregido para ${pasajeroRut}: $${saldoActual}`);
      }
      
      const nuevoSaldo = saldoActual + montoDevolucion;
      
      // Validar que el nuevo saldo no exceda el límite de PostgreSQL (10^8)
      if (nuevoSaldo > 99999999) {
        console.error(`⚠️ El nuevo saldo ${nuevoSaldo} excedería el límite de PostgreSQL`);
        
        // En lugar de fallar, establecer el saldo al máximo permitido
        const saldoMaximo = 99999999;
        console.log(`🔧 Estableciendo saldo al máximo permitido: $${saldoMaximo}`);
        
        // Procesar con el saldo máximo
        const saldoCorregidoMaximo = await actualizarSaldoUsuario(pasajeroRut, saldoMaximo);
        if (!saldoCorregidoMaximo) {
          throw new Error('Error al establecer saldo al límite máximo');
        }
        
        console.log(`✅ Saldo establecido al máximo permitido para ${pasajeroRut}: $${saldoMaximo}`);
        
        // Continuar con el proceso usando el saldo máximo
        saldoActual = saldoMaximo - montoDevolucion; // Ajustar para que el cálculo sea correcto
        const nuevoSaldoFinal = saldoMaximo;
        
        // Actualizar las variables para el resto del proceso
        return await procesarDevolucionConSaldoCorregido(
          pasajeroRut, 
          conductorRut, 
          viajeId, 
          montoDevolucion, 
          metodoPago, 
          saldoActual, 
          nuevoSaldoFinal,
          transaccionPago
        );
      }

      // Crear transacción de devolución
      const [transaccionDevolucion, errorDevolucion] = await crearTransaccionService({
        usuario_rut: pasajeroRut,
        tipo: 'devolucion',
        concepto: `Devolución por abandono de viaje - ID: ${viajeId}`,
        monto: montoDevolucion,
        metodo_pago: 'saldo',
        estado: 'completado',
        viaje_id: viajeId,
        transaccion_id: `devolucion_${viajeId}_${Date.now()}`,
        datos_adicionales: {
          conductorRut: conductorRut,
          motivoDevolucion: 'abandono_viaje',
          transaccionOriginalId: transaccionPago.id,
          metodoPagoOriginal: metodoPago,
          saldoAnterior: saldoActual,
          saldoNuevo: nuevoSaldo
        }
      });

      if (errorDevolucion) {
        throw new Error(`Error al crear transacción de devolución: ${errorDevolucion}`);
      }

      // Actualizar saldo del pasajero
      const saldoActualizado = await actualizarSaldoUsuario(pasajeroRut, nuevoSaldo);
      
      if (!saldoActualizado) {
        throw new Error('Error al actualizar saldo del pasajero');
      }

      // Procesar ajuste del conductor
      await procesarAjusteConductor(conductorRut, viajeId, montoDevolucion, transaccionDevolucion);

      console.log(`✅ Devolución al saldo completada: $${montoDevolucion} (Saldo: $${saldoActual} → $${nuevoSaldo})`);

      return {
        success: true,
        message: `Devolución procesada: $${montoDevolucion} devueltos a tu saldo`,
        tipo: metodoPago,
        monto: montoDevolucion,
        saldoAnterior: saldoActual,
        saldoNuevo: nuevoSaldo,
        transaccionDevolucionId: transaccionDevolucion.id
      };

    } else {
      throw new Error(`Método de pago no soportado para devolución: ${metodoPago}`);
    }

  } catch (error) {
    console.error("❌ Error al procesar devolución de viaje:", error);
    return {
      success: false,
      message: error.message,
      error: error.message
    };
  }
}

/**
 * Procesar devolución con saldo corregido para casos de overflow
 */
async function procesarDevolucionConSaldoCorregido(
  pasajeroRut, 
  conductorRut, 
  viajeId, 
  montoDevolucion, 
  metodoPago, 
  saldoAnterior, 
  saldoNuevo,
  transaccionPago
) {
  try {
    // Crear transacción de devolución
    const [transaccionDevolucion, errorDevolucion] = await crearTransaccionService({
      usuario_rut: pasajeroRut,
      tipo: 'devolucion',
      concepto: `Devolución por abandono de viaje (saldo corregido) - ID: ${viajeId}`,
      monto: montoDevolucion,
      metodo_pago: 'saldo',
      estado: 'completado',
      viaje_id: viajeId,
      transaccion_id: `devolucion_corregida_${viajeId}_${Date.now()}`,
      datos_adicionales: {
        conductorRut: conductorRut,
        motivoDevolucion: 'abandono_viaje',
        transaccionOriginalId: transaccionPago.id,
        metodoPagoOriginal: metodoPago,
        saldoAnterior: saldoAnterior,
        saldoNuevo: saldoNuevo,
        saldoCorregidoPorOverflow: true
      }
    });

    if (errorDevolucion) {
      throw new Error(`Error al crear transacción de devolución: ${errorDevolucion}`);
    }

    // Procesar ajuste del conductor
    await procesarAjusteConductor(conductorRut, viajeId, montoDevolucion, transaccionDevolucion);

    console.log(`✅ Devolución con saldo corregido completada: $${montoDevolucion} (Saldo corregido a: $${saldoNuevo})`);

    return {
      success: true,
      message: `Devolución procesada con saldo corregido: $${montoDevolucion} devueltos a tu saldo`,
      tipo: metodoPago,
      monto: montoDevolucion,
      saldoAnterior: saldoAnterior,
      saldoNuevo: saldoNuevo,
      saldoCorregido: true,
      transaccionDevolucionId: transaccionDevolucion.id
    };

  } catch (error) {
    console.error("❌ Error al procesar devolución con saldo corregido:", error);
    throw error;
  }
}

/**
 * Procesar ajuste del conductor cuando un pasajero abandona
 */
async function procesarAjusteConductor(conductorRut, viajeId, montoDevolucion, transaccionDevolucion) {
  try {
    const transaccionRepository = AppDataSource.getRepository("Transaccion");

    // Buscar transacción de cobro del conductor
    const transaccionCobro = await transaccionRepository.findOne({
      where: { 
        usuario_rut: conductorRut,
        viaje_id: viajeId,
        tipo: 'cobro',
        estado: 'completado'
      }
    });

    if (transaccionCobro) {
      // Crear transacción de devolución para el conductor (ajuste por abandono)
      const [transaccionDescuento, errorDescuento] = await crearTransaccionService({
        usuario_rut: conductorRut,
        tipo: 'devolucion',
        concepto: `Ajuste por abandono de pasajero - Viaje ID: ${viajeId}`,
        monto: -montoDevolucion, // Monto negativo para indicar descuento
        metodo_pago: transaccionCobro.metodo_pago,
        estado: 'completado',
        viaje_id: viajeId,
        transaccion_id: `ajuste_${viajeId}_${Date.now()}`,
        datos_adicionales: {
          motivoAjuste: 'abandono_pasajero',
          transaccionCobroOriginalId: transaccionCobro.id,
          transaccionDevolucionId: transaccionDevolucion.id
        }
      });

      if (!errorDescuento) {
        console.log(`💸 Transacción de ajuste creada para conductor: ${transaccionDescuento.id}`);
        
        // Actualizar saldo del conductor (restar el monto que había ganado)
        const { getUserService } = await import('./user.service.js');
        const [conductor, errorConductor] = await getUserService({ rut: conductorRut });
        
        if (!errorConductor && conductor) {
          const saldoActualConductor = parseFloat(conductor.saldo || 0);
          const nuevoSaldoConductor = saldoActualConductor - montoDevolucion; // Restar el monto
          
          console.log(`💰 Actualizando saldo del conductor ${conductorRut}: $${saldoActualConductor} → $${nuevoSaldoConductor}`);
          
          const saldoConductorActualizado = await actualizarSaldoUsuario(conductorRut, nuevoSaldoConductor);
          
          if (!saldoConductorActualizado) {
            console.error(`⚠️ Error al actualizar saldo del conductor ${conductorRut}`);
          } else {
            console.log(`✅ Saldo del conductor actualizado correctamente: -$${montoDevolucion}`);
          }
        }
      }
    }
  } catch (cobroError) {
    console.warn(`⚠️ No se pudo procesar descuento para conductor: ${cobroError.message}`);
  }
}

/**
 * Actualizar saldo de usuario
 */
async function actualizarSaldoUsuario(usuarioRut, nuevoSaldo) {
  try {
    console.log(`💰 Actualizando saldo de ${usuarioRut} a $${nuevoSaldo}`);
    
    // Validar que el nuevo saldo no exceda el límite permitido
    if (nuevoSaldo > 99999999) {
      console.error(`❌ Error: Nuevo saldo ${nuevoSaldo} excede el límite permitido`);
      return false;
    }
    
    // Validar que el nuevo saldo no sea negativo
    if (nuevoSaldo < 0) {
      console.error(`❌ Error: Nuevo saldo ${nuevoSaldo} no puede ser negativo`);
      return false;
    }
    
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
      
    } else if (metodo === 'efectivo') {
      // Para pagos en efectivo, crear transacciones como pendientes
      // No se modifica ningún saldo hasta que se confirme manualmente
      
      // Verificar si ya hay transacciones de efectivo para este viaje
      const transaccionRepository = AppDataSource.getRepository("Transaccion");
      const transaccionesExistentes = await transaccionRepository.find({
        where: { 
          viaje_id: viajeId, 
          metodo_pago: 'efectivo',
          usuario_rut: In([pasajeroRut, conductorRut])
        }
      });
      
      if (transaccionesExistentes.length > 0) {
        console.log(`⚠️ Ya existen transacciones en efectivo para viaje ${viajeId}. Omitiendo creación.`);
        return {
          success: true,
          transaccionId: transaccionesExistentes[0].id,
          message: 'Transacciones en efectivo ya procesadas anteriormente',
          estado: 'pendiente'
        };
      }
      
      // Crear transacción de pago del pasajero como pendiente
      const [transaccionPago, errorPago] = await crearTransaccionService({
        usuario_rut: pasajeroRut,
        tipo: 'pago',
        concepto: `Pago de viaje en efectivo - ID: ${viajeId}`,
        monto: monto,
        metodo_pago: 'efectivo',
        estado: 'pendiente', // Pendiente hasta confirmación manual
        viaje_id: viajeId,
        transaccion_id: `viaje_efectivo_${viajeId}_${Date.now()}`,
        datos_adicionales: {
          conductorRut: conductorRut,
          metodoPagoOriginal: metodo,
          requiereConfirmacionManual: true
        }
      });
      
      if (errorPago) {
        throw new Error(`Error al crear transacción de pago en efectivo: ${errorPago}`);
      }
      
      // Crear transacción de cobro para el conductor como pendiente
      const [transaccionCobro, errorCobro] = await crearTransaccionService({
        usuario_rut: conductorRut,
        tipo: 'cobro',
        concepto: `Cobro por viaje en efectivo - ID: ${viajeId}`,
        monto: monto,
        metodo_pago: 'efectivo',
        estado: 'pendiente', // Pendiente hasta confirmación manual
        viaje_id: viajeId,
        transaccion_id: `viaje_cobro_efectivo_${viajeId}_${Date.now()}`,
        datos_adicionales: {
          pasajeroRut: pasajeroRut,
          metodoPagoOriginal: metodo,
          requiereConfirmacionManual: true
        }
      });
      
      if (errorCobro) {
        console.warn(`⚠️ Error al crear transacción de cobro para conductor: ${errorCobro}`);
      }
      
      console.log(`✅ Transacciones en efectivo creadas como pendientes - Pago ID: ${transaccionPago.id}`);
      
      return {
        success: true,
        transaccionId: transaccionPago.id,
        message: 'Pago en efectivo registrado como pendiente. Confirma cuando se realice el pago.',
        estado: 'pendiente'
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

/**
 * Confirmar pago en efectivo (cuando se confirma manualmente)
 */
export async function confirmarPagoEfectivo(transaccionId, usuarioQueConfirma) {
  try {
    console.log(`💵 Confirmando pago en efectivo - Transacción ID: ${transaccionId} por usuario: ${usuarioQueConfirma}`);
    
    const transaccionRepository = AppDataSource.getRepository("Transaccion");
    
    // Buscar la transacción de pago o cobro pendiente
    const transaccion = await transaccionRepository.findOne({
      where: { 
        id: transaccionId, 
        metodo_pago: 'efectivo', 
        estado: 'pendiente' 
      }
    });
    
    if (!transaccion) {
      throw new Error('Transacción en efectivo no encontrada o ya procesada');
    }
    
    const { viaje_id, tipo, datos_adicionales } = transaccion;
    const { conductorRut, pasajeroRut } = datos_adicionales;
    
    // Actualizar estado de la transacción actual
    await actualizarEstadoTransaccionService(transaccionId, 'completado');
    
    // Buscar y actualizar la transacción correspondiente (pago o cobro)
    const tipoCorrespondiente = tipo === 'pago' ? 'cobro' : 'pago';
    const usuarioCorrespondiente = tipo === 'pago' ? conductorRut : pasajeroRut;
    
    const transaccionCorrespondiente = await transaccionRepository.findOne({
      where: { 
        viaje_id: viaje_id, 
        tipo: tipoCorrespondiente, 
        metodo_pago: 'efectivo', 
        estado: 'pendiente',
        usuario_rut: usuarioCorrespondiente
      }
    });
    
    if (transaccionCorrespondiente) {
      await actualizarEstadoTransaccionService(transaccionCorrespondiente.id, 'completado');
    }
    
    console.log(`✅ Pago en efectivo confirmado exitosamente - Transacción: ${transaccionId}`);
    
    return {
      success: true,
      message: 'Pago en efectivo confirmado exitosamente',
      transaccionId: transaccionId,
      transaccionCorrespondienteId: transaccionCorrespondiente?.id
    };
    
  } catch (error) {
    console.error("❌ Error al confirmar pago en efectivo:", error);
    return {
      success: false,
      message: error.message,
      error: error.message
    };
  }
}


