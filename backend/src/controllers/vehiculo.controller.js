"use strict";
import {
  createVehiculoService,
  getVehiculosByUserService,
  updateVehiculoService,
  deleteVehiculoService,
} from "../services/vehiculo.service.js";
import {
  vehiculoBodyValidation,
  vehiculoQueryValidation,
} from "../validations/vehiculo.validation.js";
import {
  handleErrorClient,
  handleErrorServer,
  handleSuccess,
} from "../handlers/responseHandlers.js";

export async function createVehiculo(req, res) {
  try {
    const { body } = req;
    const userRut = req.user.rut; // Obtenido del middleware de autenticación

    console.log('🚗 Creando vehículo - Usuario:', userRut);
    console.log('📝 Datos recibidos:', body);

    const { error: bodyError } = vehiculoBodyValidation.validate(body);

    if (bodyError) {
      console.log('❌ Error de validación:', bodyError.message);
      return handleErrorClient(
        res,
        400,
        "Error de validación en los datos enviados",
        bodyError.message,
      );
    }

    console.log('✅ Validaciones pasadas, creando vehículo...');

    const [vehiculo, vehiculoError] = await createVehiculoService(body, userRut);

    if (vehiculoError) {
      console.log('❌ Error del servicio:', vehiculoError);
      return handleErrorClient(res, 400, "Error creando vehículo", vehiculoError);
    }

    console.log('✅ Vehículo creado exitosamente');
    handleSuccess(res, 201, "Vehículo creado correctamente", vehiculo);
  } catch (error) {
    console.error('💥 Error inesperado en createVehiculo:', error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function getMisVehiculos(req, res) {
  try {
    const userRut = req.user.rut; // Obtenido del middleware de autenticación

    console.log('🔍 Obteniendo vehículos del usuario:', userRut);

    const [vehiculos, vehiculosError] = await getVehiculosByUserService(userRut);

    if (vehiculosError) {
      console.log('❌ Error del servicio:', vehiculosError);
      return handleErrorClient(res, 404, vehiculosError);
    }

    console.log('✅ Vehículos obtenidos exitosamente');
    handleSuccess(res, 200, "Vehículos encontrados", vehiculos);
  } catch (error) {
    console.error('💥 Error inesperado en getMisVehiculos:', error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function updateVehiculo(req, res) {
  try {
    const { patente } = req.params;
    const { body } = req;
    const userRut = req.user.rut;

    console.log('🔧 Actualizando vehículo - Patente:', patente, 'Usuario:', userRut);
    console.log('📝 Datos recibidos:', body);

    const { error: queryError } = vehiculoQueryValidation.validate({ patente });
    if (queryError) {
      console.log('❌ Error de validación de patente:', queryError.message);
      return handleErrorClient(
        res,
        400,
        "Error de validación en la patente",
        queryError.message,
      );
    }

    const { error: bodyError } = vehiculoBodyValidation.validate(body);
    if (bodyError) {
      console.log('❌ Error de validación del cuerpo:', bodyError.message);
      return handleErrorClient(
        res,
        400,
        "Error de validación en los datos enviados",
        bodyError.message,
      );
    }

    const [vehiculo, vehiculoError] = await updateVehiculoService(patente, body, userRut);

    if (vehiculoError) {
      console.log('❌ Error del servicio:', vehiculoError);
      return handleErrorClient(res, 400, "Error actualizando vehículo", vehiculoError);
    }

    console.log('✅ Vehículo actualizado exitosamente');
    handleSuccess(res, 200, "Vehículo actualizado correctamente", vehiculo);
  } catch (error) {
    console.error('💥 Error inesperado en updateVehiculo:', error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function deleteVehiculo(req, res) {
  try {
    const { patente } = req.params;
    const userRut = req.user.rut;

    console.log('🗑️ Eliminando vehículo - Patente:', patente, 'Usuario:', userRut);

    const { error: queryError } = vehiculoQueryValidation.validate({ patente });
    if (queryError) {
      console.log('❌ Error de validación de patente:', queryError.message);
      return handleErrorClient(
        res,
        400,
        "Error de validación en la patente",
        queryError.message,
      );
    }

    const [vehiculo, vehiculoError] = await deleteVehiculoService(patente, userRut);

    if (vehiculoError) {
      console.log('❌ Error del servicio:', vehiculoError);
      return handleErrorClient(res, 404, "Error eliminando vehículo", vehiculoError);
    }

    console.log('✅ Vehículo eliminado exitosamente');
    handleSuccess(res, 200, "Vehículo eliminado correctamente", vehiculo);
  } catch (error) {
    console.error('💥 Error inesperado en deleteVehiculo:', error);
    handleErrorServer(res, 500, error.message);
  }
}
