"use strict";
import User from "../entity/user.entity.js";
import { AppDataSource } from "../config/configDb.js";
import { comparePassword, encryptPassword } from "../helpers/bcrypt.helper.js";
import { Not, IsNull } from "typeorm";

export async function getUserService(query) {
  try {
    const { rut, email } = query;

    const userRepository = AppDataSource.getRepository(User);

    const userFound = await userRepository.findOne({
      where: [{ rut: rut }, { email: email }],
    });

    if (!userFound) return [null, "Usuario no encontrado"];

    const { password, ...userData } = userFound;

    return [userData, null];
  } catch (error) {
    console.error("Error obtener el usuario:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function getUserGService(query) {
  try {
    const { email } = query;

    const userRepository = AppDataSource.getRepository(User);

    const userFound = await userRepository.findOne({
      where: [{ email: email }],
    });

    if (!userFound) return [null, "Usuario no encontrado"];

    const { password, ...userData } = userFound;

    return [userData, null];
  } catch (error) {
    console.error("Error obtener el usuario:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function getUsersService() {
  try {
    const userRepository = AppDataSource.getRepository(User);

    const users = await userRepository.find();

    if (!users || users.length === 0) return [null, "No hay usuarios"];

    const usersData = users.map(({ password, ...user }) => user);

    return [usersData, null];
  } catch (error) {
    console.error("Error al obtener a los usuarios:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function searchUserService(query) {
  try {
    const { email } = query;

    const userRepository = AppDataSource.getRepository(User);

    const userFound = await userRepository.findOne({
      where: [{ email: email }],
    });

    if (!userFound) return [null, "Usuario no encontrado"];

    const { password, ...userData } = userFound;

    return [userData, null];
  } catch (error) {
    console.error("Error al buscar el usuario:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function buscarRutService(query) {
  try {
    const { rut } = query;
    const userRepository = AppDataSource.getRepository(User);
    const userFound = await userRepository.findOne({
      where: { rut: rut },
    });
    if (!userFound) return [null, "Usuario no encontrado"];
    const { password, ...userData } = userFound;
    return [userData, null];
  } catch (error) {
    console.error("Error al buscar el usuario por RUT:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function updateUserService(query, body) {
  try {
    const { rut, email } = query;

    const userRepository = AppDataSource.getRepository(User);

    const userFound = await userRepository.findOne({
      where: [{ rut: rut }, { email: email }],
    });

    if (!userFound) return [null, "Usuario no encontrado"];

    const existingUser = await userRepository.findOne({
      where: [{ rut: body.rut }, { email: body.email }],
    });

    if (existingUser && existingUser.id !== userFound.id) {
      return [null, "Ya existe un usuario con el mismo rut o email"];
    }

    if (body.password) {
      const matchPassword = await comparePassword(
        body.password,
        userFound.password,
      );

      if (!matchPassword) return [null, "La contraseña no coincide"];
    }

    const dataUserUpdate = {
      nombreCompleto: body.nombreCompleto,
      rut: body.rut,
      email: body.email,
      rol: body.rol,
      carrera: body.carrera,
      descripcion: body.descripcion,
      fechaNacimiento: body.fechaNacimiento,
      updatedAt: new Date(),
    };

    if (body.newPassword && body.newPassword.trim() !== "") {
      dataUserUpdate.password = await encryptPassword(body.newPassword);
    }

    await userRepository.update({ rut: userFound.rut }, dataUserUpdate);

    const userData = await userRepository.findOne({
      where: { rut: userFound.rut },
    });

    if (!userData) {
      return [null, "Usuario no encontrado después de actualizar"];
    }

    const { password, ...userUpdated } = userData;

    return [userUpdated, null];
  } catch (error) {
    console.error("Error al modificar un usuario:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function deleteUserService(query) {
  try {
    const {rut, email } = query;

    const userRepository = AppDataSource.getRepository(User);

    const userFound = await userRepository.findOne({
      where: [{ rut: rut }, { email: email }],
    });

    if (!userFound) return [null, "Usuario no encontrado"];

    if (userFound.rol === "administrador") {
      return [null, "No se puede eliminar un usuario con rol de administrador"];
    }

    const userDeleted = await userRepository.remove(userFound);

    const { password, ...dataUser } = userDeleted;

    return [dataUser, null];
  } catch (error) {
    console.error("Error al eliminar un usuario:", error);
    return [null, "Error interno del servidor"];
  }
}


export function calcularCalificacionBayesiana(promedioUsuario, cantidadValoraciones, promedioGlobal, minimoValoraciones) {
  try {
    // Fórmula bayesiana
    const calificacionAjustada = 
      ((cantidadValoraciones * promedioUsuario) + (minimoValoraciones * promedioGlobal)) / 
      (cantidadValoraciones + minimoValoraciones);

    return calificacionAjustada;
  } catch (error) {
    console.error("Error al calcular la calificación bayesiana:", error);
    return null;
  }
}

// Nueva función para calcular el promedio global de clasificaciones
export async function obtenerPromedioGlobalService() {
  try {
    const userRepository = AppDataSource.getRepository(User);

    // Obtener todos los usuarios que tienen clasificación (usando sintaxis correcta para PostgreSQL)
    const usuarios = await userRepository.find({
      where: {
        clasificacion: Not(IsNull()) // Sintaxis correcta de TypeORM para "no es null"
      },
      select: ['clasificacion'] // Solo necesitamos la clasificación para calcular el promedio
    });

    if (!usuarios || usuarios.length === 0) {
      // Si no hay usuarios con clasificación, retornar promedio por defecto
      return [3.0, null];
    }

    // Filtrar usuarios que realmente tengan clasificación válida
    const usuariosConClasificacion = usuarios.filter(user => 
      user.clasificacion !== null && 
      user.clasificacion !== undefined && 
      !isNaN(user.clasificacion)
    );

    if (usuariosConClasificacion.length === 0) {
      return [3.0, null];
    }

    // Calcular la suma de todas las clasificaciones
    const sumaClasificaciones = usuariosConClasificacion.reduce((suma, user) => {
      return suma + parseFloat(user.clasificacion);
    }, 0);

    // Calcular el promedio
    const promedioGlobal = sumaClasificaciones / usuariosConClasificacion.length;

    console.log(`Promedio global calculado: ${promedioGlobal} de ${usuariosConClasificacion.length} usuarios`);

    return [promedioGlobal, null];
  } catch (error) {
    console.error("Error al calcular el promedio global:", error);
    // En caso de error, retornar promedio por defecto
    return [3.0, "Error al calcular promedio global, usando valor por defecto"];
  }
}