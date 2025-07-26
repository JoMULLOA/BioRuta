"use strict";
import { AppDataSource } from "../config/configDb.js";
import User from "../entity/user.entity.js";
import VehiculoSchema from "../entity/vehiculo.entity.js";

export async function createVehiculoService(vehiculoData, userRut) {
  try {
    const vehiculoRepository = AppDataSource.getRepository("Vehiculo");
    const userRepository = AppDataSource.getRepository(User);

    // Verificar que el usuario existe
    const user = await userRepository.findOne({ where: { rut: userRut } });
    if (!user) {
      return [null, "Usuario no encontrado"];
    }

    // Verificar que la patente no existe
    const existingVehiculo = await vehiculoRepository.findOne({
      where: { patente: vehiculoData.patente }
    });

    if (existingVehiculo) {
      return [null, "Ya existe un vehículo con esta patente"];
    }

    // Crear el vehículo
    const vehiculo = vehiculoRepository.create({
      ...vehiculoData,
      propietario: user
    });

    const savedVehiculo = await vehiculoRepository.save(vehiculo);

    // Retornar sin la relación del propietario para evitar datos sensibles
    const { propietario, ...vehiculoSinPropietario } = savedVehiculo;

    return [vehiculoSinPropietario, null];
  } catch (error) {
    console.error("Error al crear vehículo:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function getVehiculosByUserService(userRut) {
  try {
    const vehiculoRepository = AppDataSource.getRepository("Vehiculo");

    const vehiculos = await vehiculoRepository.find({
      where: { 
        propietario: { rut: userRut }
      },
      relations: ["propietario"]
    });

    // Formatear datos para el frontend
    const vehiculosFormateados = vehiculos.map(vehiculo => {
      return {
        patente: vehiculo.patente,
        tipo: vehiculo.tipo,
        marca: vehiculo.marca,
        modelo: vehiculo.modelo,
        año: vehiculo.año,
        color: vehiculo.color,
        nro_asientos: vehiculo.nro_asientos,
        documentacion: vehiculo.documentacion,
        tipoCombustible: vehiculo.tipoCombustible,
      };
    });

    return [vehiculosFormateados, null];
  } catch (error) {
    console.error("Error al obtener vehículos del usuario:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function updateVehiculoService(patente, vehiculoData, userRut) {
  try {
    const vehiculoRepository = AppDataSource.getRepository("Vehiculo");

    // Verificar que el vehículo existe y pertenece al usuario
    const vehiculo = await vehiculoRepository.findOne({
      where: { 
        patente: patente,
        propietario: { rut: userRut }
      },
      relations: ["propietario"]
    });

    if (!vehiculo) {
      return [null, "Vehículo no encontrado o no tienes permisos para editarlo"];
    }

    // Actualizar datos
    Object.assign(vehiculo, vehiculoData);
    const updatedVehiculo = await vehiculoRepository.save(vehiculo);

    // Retornar sin la relación del propietario
    const { propietario, ...vehiculoSinPropietario } = updatedVehiculo;

    return [vehiculoSinPropietario, null];
  } catch (error) {
    console.error("Error al actualizar vehículo:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function deleteVehiculoService(patente, userRut) {
  try {
    const vehiculoRepository = AppDataSource.getRepository("Vehiculo");

    // Verificar que el vehículo existe y pertenece al usuario
    const vehiculo = await vehiculoRepository.findOne({
      where: { 
        patente: patente,
        propietario: { rut: userRut }
      },
      relations: ["propietario"]
    });

    if (!vehiculo) {
      return [null, "Vehículo no encontrado o no tienes permisos para eliminarlo"];
    }

    await vehiculoRepository.remove(vehiculo);

    return [{ patente: patente }, null];
  } catch (error) {
    console.error("Error al eliminar vehículo:", error);
    return [null, "Error interno del servidor"];
  }
}
