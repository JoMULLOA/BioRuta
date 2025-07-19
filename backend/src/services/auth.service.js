"use strict";
import User from "../entity/user.entity.js";
import jwt from "jsonwebtoken";
import { AppDataSource } from "../config/configDb.js";
import { comparePassword, encryptPassword } from "../helpers/bcrypt.helper.js";
import { ACCESS_TOKEN_SECRET } from "../config/configEnv.js";

export async function loginService(user) {
  try {
    // Debug: Verificar que el ACCESS_TOKEN_SECRET esté disponible
    console.log("🔧 DEBUG - ACCESS_TOKEN_SECRET disponible:", ACCESS_TOKEN_SECRET ? "✅ Sí" : "❌ No");
    if (!ACCESS_TOKEN_SECRET) {
      console.error("❌ CRITICAL: ACCESS_TOKEN_SECRET no está definido!");
      return [null, "Error de configuración del servidor"];
    }

    const userRepository = AppDataSource.getRepository(User);
    const { email, password } = user;

    const createErrorMessage = (dataInfo, message) => ({
      dataInfo,
      message
    });
    const userFound = await userRepository.findOne({
      where: { email }
    });

    if (!userFound) {
      return [null, createErrorMessage("email", "El correo electrónico es incorrecto")];
    }

    const isMatch = await comparePassword(password, userFound.password);

    if (!isMatch) {
      return [null, createErrorMessage("password", "La contraseña es incorrecta")];
    }

    const payload = {
      nombreCompleto: userFound.nombreCompleto,
      email: userFound.email,
      rut: userFound.rut,
      rol: userFound.rol,
    };

    console.log("🔧 DEBUG - Generando token JWT con payload:", payload);
    console.log("🔧 DEBUG - Usando ACCESS_TOKEN_SECRET (primeros 20 chars):", ACCESS_TOKEN_SECRET?.substring(0, 20) + "...");

    const accessToken = jwt.sign(payload, ACCESS_TOKEN_SECRET, {
      expiresIn: "1d",
    });

    console.log("🔧 DEBUG - Token generado exitosamente, longitud:", accessToken?.length);

    return [accessToken, null];
  } catch (error) {
    console.error("Error al iniciar sesión:", error);
    return [null, "Error interno del servidor"];
  }
}


export async function registerService(user) {
  try {
    const userRepository = AppDataSource.getRepository(User);
    console.log("Datos recibidos en el registro:", user); // Verificar que los datos llegan correctamente
    const { nombreCompleto, email, rut, rol, password, carrera, fechaNacimiento, genero } = user;

    // Verificación de existencia de email o rut
    const existingEmailUser = await userRepository.findOne({ where: { email } });
    if (existingEmailUser) {
      return [null, { field: "email", message: "Correo electrónico en uso" }];
    }

    const existingRutUser = await userRepository.findOne({ where: { rut } });
    if (existingRutUser) {
      return [null, { field: "rut", message: "Rut ya asociado a una cuenta" }];
    }

    console.log("Rol recibido en la solicitud:", rol); // Verificar que rol llega correctamente
    
    const newUser = userRepository.create({
      nombreCompleto,
      email,
      rut,
      password: await encryptPassword(password),
      rol,
      carrera,
      fechaNacimiento,
      genero,
    });
    await userRepository.save(newUser);

    const { password: _, ...dataUser } = newUser; // Excluye la contraseña del objeto devuelto
    return [dataUser, null];
  } catch (error) {
    console.error("Error al registrar un usuario:", error);
    return [null, "Error interno del servidor"];
  }
}