"use strict";
import {
  deleteUserService,
  getUserService,
  getUserGService,
  getUsersService,
  updateUserService,
  searchUserService,
  buscarRutService,
  calcularCalificacionBayesiana,
  obtenerPromedioGlobalService,
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

    // Importar el servicio dentro de la función
    const { getVehiculosByUserService } = await import("../services/vehiculo.service.js");

    const [vehiculos, vehiculosError] = await getVehiculosByUserService(userRut);

    if (vehiculosError) {
      return handleErrorClient(res, 404, vehiculosError);
    }

    handleSuccess(res, 200, "Vehículos encontrados", vehiculos);
  } catch (error) {
    console.error("Error al obtener vehículos del usuario:", error);
    handleErrorServer(res, 500, error.message);
  }
}

//Bayesiano

export async function calcularCalificacion(req, res) {
  try {
    const { promedioUsuario, cantidadValoraciones, promedioGlobal, minimoValoraciones } = req.body;

    if (typeof promedioUsuario !== 'number' || typeof cantidadValoraciones !== 'number' ||
        typeof promedioGlobal !== 'number' || typeof minimoValoraciones !== 'number') {
      return handleErrorClient(res, 400, "Todos los campos deben ser números");
    }

    const calificacionAjustada = calcularCalificacionBayesiana(
      promedioUsuario,
      cantidadValoraciones,
      promedioGlobal,
      minimoValoraciones
    );

    if (calificacionAjustada === null) {
      return handleErrorServer(res, 500, "Error al calcular la calificación");
    }

    handleSuccess(res, 200, "Calificación calculada correctamente", { calificacionAjustada });
  } catch (error) {
    handleErrorServer(res, 500, error.message);
  }
}

export async function obtenerPromedioGlobal(req, res) {
  try {
    const [promedioGlobal, error] = await obtenerPromedioGlobalService();

    if (error) {
      console.warn("Advertencia al calcular promedio global:", error);
      // Aún así retornamos el promedio por defecto
    }

    handleSuccess(res, 200, "Promedio global obtenido correctamente", { 
      promedioGlobal: promedioGlobal,
      mensaje: error || "Cálculo exitoso"
    });
  } catch (error) {
    console.error("Error en obtenerPromedioGlobal controller:", error);
    handleErrorServer(res, 500, error.message);
  }
}