"use strict";
import { AppDataSource } from "../config/configDb.js";

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
