"use strict";
import {
  deleteUserService,
  getUserService,
  getUserGService,
  getUsersService,
  updateUserService,
  searchUserService,
  buscarRutService,
} from "../services/user.service.js";
import {
  userBodyValidation,
  userQueryValidation,
} from "../validations/user.validation.js";
import {
  handleErrorClient,
  handleErrorServer,
  handleSuccess,
} from "../handlers/responseHandlers.js";


export async function getUser(req, res) {
  try {
    const { rut, email } = req.query;

    const { error } = userQueryValidation.validate({ rut, email });

    if (error) return handleErrorClient(res, 400, error.message);

    const [user, errorUser] = await getUserService({ rut, email });

    if (errorUser) return handleErrorClient(res, 404, errorUser);

    handleSuccess(res, 200, "Usuario encontrado", user);
  } catch (error) {
    handleErrorServer(res, 500, error.message);
  }
}

export async function getUsers(req, res) {
  try {
    const [users, errorUsers] = await getUsersService();

    if (errorUsers) return handleErrorClient(res, 404, errorUsers);

    users.length === 0
      ? handleSuccess(res, 204)
      : handleSuccess(res, 200, "Usuarios encontrados", users);
  } catch (error) {
    handleErrorServer(
      res,
      500,
      error.message,
    );
  }
}

export async function searchUser(req, res) {
  try {
    const { email } = req.query;

    const { error: queryError } = userQueryValidation.validate({ email });

    if (queryError) {
      return handleErrorClient(
        res,
        400,
        "Error de validación en la consulta",
        queryError.message,
      );
    }

    const [user, errorUser] = await searchUserService({ email });

    if (errorUser) return handleErrorClient(res, 404, errorUser);
    console.log("user", user);
    handleSuccess(res, 200, "Usuario encontrado", user);
  } catch (error) {
    handleErrorServer(res, 500, error.message);
  }
}

export async function buscarRut(req, res) {
  try {
    const { rut } = req.query;

    const { error: queryError } = userQueryValidation.validate({ rut });
    if (queryError) {
      return handleErrorClient(
        res,
        400,  
        "Error de validación en la consulta",
        queryError.message,
      );
    }
    const [user, errorUser] = await buscarRutService({ rut });
    if (errorUser) return handleErrorClient(res, 404, errorUser);
    handleSuccess(res, 200, "Usuario encontrado", user);
  } catch (error) {
    handleErrorServer(res, 500, error.message);
  }
}

export async function updateUser(req, res) {
  try {
    const { rut, email } = req.query;
    const { body } = req;

    console.log('🔍 UpdateUser - Query params:', { rut, email });
    console.log('📝 UpdateUser - Body received:', body);

    const { error: queryError } = userQueryValidation.validate({
      rut,
      email,
    });

    if (queryError) {
      console.log('❌ Query validation error:', queryError.message);
      return handleErrorClient(
        res,
        400,
        "Error de validación en la consulta",
        queryError.message,
      );
    }

    const { error: bodyError } = userBodyValidation.validate(body);

    if (bodyError) {
      console.log('❌ Body validation error:', bodyError.message);
      return handleErrorClient(
        res,
        400,
        "Error de validación en los datos enviados",
        bodyError.message,
      );
    }

    console.log('✅ Validaciones pasadas, actualizando usuario...');

    const [user, userError] = await updateUserService({ rut, email }, body);

    if (userError) {
      console.log('❌ Service error:', userError);
      return handleErrorClient(res, 400, "Error modificando al usuario", userError);
    }

    console.log('✅ Usuario actualizado exitosamente');
    handleSuccess(res, 200, "Usuario modificado correctamente", user);
  } catch (error) {
    console.error('💥 Unexpected error in updateUser:', error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function deleteUser(req, res) {
  try {
    const { rut, email } = req.query;

    const { error: queryError } = userQueryValidation.validate({
      rut,
      email,
    });

    if (queryError) {
      return handleErrorClient(
        res,
        400,
        "Error de validación en la consulta",
        queryError.message,
      );
    }

    const [userDelete, errorUserDelete] = await deleteUserService({
      rut,
      email,
    });

    if (errorUserDelete) return handleErrorClient(res, 404, "Error eliminado al usuario", errorUserDelete);

    handleSuccess(res, 200, "Usuario eliminado correctamente", userDelete);
  } catch (error) {
    handleErrorServer(res, 500, error.message);
  }
}

export async function getMisVehiculos(req, res) {
  try {
    const userRut = req.user.rut;

    // Importar el repositorio dentro de la función para evitar problemas de importación circular
    const { AppDataSource } = await import("../config/configDb.js");
    const vehiculoRepository = AppDataSource.getRepository("Vehiculo");

    const vehiculos = await vehiculoRepository.find({
      where: { 
        propietario: { rut: userRut }
      },
      relations: ["propietario"]
    });

    // Formatear datos para el frontend
    const vehiculosFormateados = vehiculos.map(vehiculo => {
      // Extraer marca del modelo (asumiendo formato "Marca Modelo")
      const modeloCompleto = vehiculo.modelo || '';
      const partesModelo = modeloCompleto.split(' ');
      const marca = partesModelo[0] || 'Desconocida';
      const modelo = partesModelo.slice(1).join(' ') || modeloCompleto;

      return {
        patente: vehiculo.patente,
        marca: marca,
        modelo: modelo,
        modeloCompleto: vehiculo.modelo,
        color: vehiculo.color,
        nro_asientos: vehiculo.nro_asientos,
        documentacion: vehiculo.documentacion
      };
    });

    handleSuccess(res, 200, "Vehículos encontrados", vehiculosFormateados);
  } catch (error) {
    console.error("Error al obtener vehículos del usuario:", error);
    handleErrorServer(res, 500, error.message);
  }
}