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

    // Si solo se está actualizando el saldo, hacer actualización directa
    if (body.saldo !== undefined && Object.keys(body).length === 1) {
      await userRepository.update(
        { rut: userFound.rut }, 
        { 
          saldo: body.saldo,
          updatedAt: new Date() 
        }
      );

      const userData = await userRepository.findOne({
        where: { rut: userFound.rut },
      });

      if (!userData) {
        return [null, "Usuario no encontrado después de actualizar"];
      }

      const { password, ...userUpdated } = userData;
      return [userUpdated, null];
    }

    // Si se están actualizando tarjetas, hacer actualización directa
    if (body.tarjetas !== undefined && Object.keys(body).length === 1) {
      await userRepository.update(
        { rut: userFound.rut }, 
        { 
          tarjetas: body.tarjetas,
          updatedAt: new Date() 
        }
      );

      const userData = await userRepository.findOne({
        where: { rut: userFound.rut },
      });

      if (!userData) {
        return [null, "Usuario no encontrado después de actualizar"];
      }

      const { password, ...userUpdated } = userData;
      return [userUpdated, null];
    }

    // Validación para actualizaciones completas del perfil
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

export async function deleteUserService(query) {
  try {
    const { rut, email } = query;

    const userRepository = AppDataSource.getRepository(User);

    // Buscar el usuario por RUT o email
    const userFound = await userRepository.findOne({
      where: [{ rut: rut }, { email: email }],
    });

    if (!userFound) return [null, "Usuario no encontrado"];

    // Verificar que no sea un administrador (opcional - medida de seguridad)
    if (userFound.rol === 'administrador') {
      return [null, "No se puede eliminar un usuario administrador"];
    }

    // Importar las entidades relacionadas
    const Amistad = await import("../entity/amistad.entity.js");
    const SolicitudAmistad = await import("../entity/solicitudAmistad.entity.js");
    const Notificacion = await import("../entity/notificacion.entity.js");
    const Vehiculo = await import("../entity/vehiculo.entity.js");
    const ChatPersonal = await import("../entity/chatPersonal.entity.js");
    const Mensaje = await import("../entity/mensaje.entity.js");

    // Obtener los repositorios
    const amistadRepository = AppDataSource.getRepository(Amistad.default);
    const solicitudRepository = AppDataSource.getRepository(SolicitudAmistad.default);
    const notificacionRepository = AppDataSource.getRepository(Notificacion.default);
    const vehiculoRepository = AppDataSource.getRepository(Vehiculo.default);
    const chatPersonalRepository = AppDataSource.getRepository(ChatPersonal.default);
    const mensajeRepository = AppDataSource.getRepository(Mensaje.default);

    console.log(`🗑️ Eliminando relaciones del usuario: ${userFound.rut}`);

    // 1. Eliminar amistades donde el usuario sea participante
    const amistades = await amistadRepository.find({
      where: [
        { rutUsuario1: userFound.rut },
        { rutUsuario2: userFound.rut }
      ]
    });
    
    if (amistades.length > 0) {
      await amistadRepository.remove(amistades);
      console.log(`✅ Eliminadas ${amistades.length} amistades`);
    }

    // 2. Eliminar solicitudes de amistad (enviadas y recibidas)
    const solicitudes = await solicitudRepository.find({
      where: [
        { rutEmisor: userFound.rut },
        { rutReceptor: userFound.rut }
      ]
    });

    if (solicitudes.length > 0) {
      await solicitudRepository.remove(solicitudes);
      console.log(`✅ Eliminadas ${solicitudes.length} solicitudes de amistad`);
    }

    // 3. Eliminar notificaciones del usuario (como receptor y emisor)
    const notificaciones = await notificacionRepository.find({
      where: [
        { rutReceptor: userFound.rut },
        { rutEmisor: userFound.rut }
      ]
    });

    if (notificaciones.length > 0) {
      await notificacionRepository.remove(notificaciones);
      console.log(`✅ Eliminadas ${notificaciones.length} notificaciones`);
    }

    // 4. Eliminar vehículos del usuario
    // Como los vehículos tienen CASCADE, deberían eliminarse automáticamente,
    // pero podemos hacerlo explícitamente para mayor seguridad
    try {
      const vehiculos = await vehiculoRepository.find({
        relations: ['propietario'],
        where: { propietario: { rut: userFound.rut } }
      });

      if (vehiculos.length > 0) {
        await vehiculoRepository.remove(vehiculos);
        console.log(`✅ Eliminados ${vehiculos.length} vehículos`);
      }
    } catch (vehiculoError) {
      console.warn("⚠️ Error eliminando vehículos:", vehiculoError.message);
      // Los vehículos deberían eliminarse automáticamente por CASCADE
    }

    // 5. Eliminar chats personales donde el usuario participe
    const chats = await chatPersonalRepository.find({
      where: [
        { rutUsuario1: userFound.rut },
        { rutUsuario2: userFound.rut }
      ]
    });

    if (chats.length > 0) {
      await chatPersonalRepository.remove(chats);
      console.log(`✅ Eliminados ${chats.length} chats personales`);
    }

    // 6. Eliminar mensajes del usuario
    const mensajes = await mensajeRepository.find({
      where: { rutEmisor: userFound.rut }
    });

    if (mensajes.length > 0) {
      await mensajeRepository.remove(mensajes);
      console.log(`✅ Eliminados ${mensajes.length} mensajes`);
    }

    // 7. Eliminar viajes de MongoDB (importar modelo de viaje de Mongoose)
    try {
      const mongoose = await import("mongoose");
      if (mongoose.default.connection.readyState === 1) {
        // Eliminar viajes donde el usuario sea el conductor
        const resultViajes = await mongoose.default.connection.db.collection('viajes').deleteMany({
          usuario_rut: userFound.rut
        });
        console.log(`✅ Eliminados ${resultViajes.deletedCount} viajes de MongoDB`);

        // Eliminar el usuario de la lista de pasajeros en otros viajes
        const resultPasajeros = await mongoose.default.connection.db.collection('viajes').updateMany(
          { "pasajeros.rut": userFound.rut },
          { $pull: { pasajeros: { rut: userFound.rut } } }
        );
        console.log(`✅ Usuario removido de ${resultPasajeros.modifiedCount} viajes como pasajero`);
      }
    } catch (mongoError) {
      console.warn("⚠️ Error eliminando datos de MongoDB:", mongoError.message);
      // No fallar la eliminación completa por errores de MongoDB
    }

    // 8. Finalmente, eliminar el usuario
    await userRepository.remove(userFound);
    console.log(`✅ Usuario ${userFound.rut} eliminado exitosamente`);

    // Retornar los datos del usuario eliminado (sin contraseña)
    const { password, ...userData } = userFound;

    return [userData, null];
  } catch (error) {
    console.error("Error al eliminar usuario:", error);
    return [null, "Error interno del servidor"];
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

export async function actualizarTokenFCMService(rut, fcmToken) {
  try {
    const userRepository = AppDataSource.getRepository(User);

    // Buscar el usuario por RUT
    const user = await userRepository.findOne({
      where: { rut: rut }
    });

    if (!user) {
      return [null, "Usuario no encontrado"];
    }

    // Actualizar el token FCM
    user.fcmToken = fcmToken;
    
    await userRepository.save(user);

    console.log(`✅ Token FCM actualizado para usuario ${rut}`);
    return [{ rut: rut, tokenActualizado: true }, null];
  } catch (error) {
    console.error("Error al actualizar token FCM:", error);
    return [null, "Error interno del servidor al actualizar token FCM"];
  }
}

export async function obtenerUserByRut(rut) {
  try {
    const userRepository = AppDataSource.getRepository(User);

    const user = await userRepository.findOne({
      where: { rut: rut }
    });

    if (!user) {
      return [null, "Usuario no encontrado"];
    }

    const { password, ...userData } = user;
    return [userData, null];
  } catch (error) {
    console.error("Error al obtener usuario por RUT:", error);
    return [null, "Error interno del servidor"];
  }
}