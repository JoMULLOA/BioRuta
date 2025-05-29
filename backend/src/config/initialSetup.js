"use strict";
import User from "../entity/user.entity.js";
import Vehiculo from "../entity/vehiculo.entity.js";
import { AppDataSource } from "./configDb.js";
import { encryptPassword } from "../helpers/bcrypt.helper.js";

async function createInitialData() {
  try {
    // Crear Usuarios
    const userRepository = AppDataSource.getRepository(User);
    const userCount = await userRepository.count();
    let user1 = null;

    if (userCount === 0) {
      user1 = userRepository.create({
        nombreCompleto: "Usuario1",
        rut: "22.333.111-4",
        email: "usuario1@alumnos.ubiobio.cl",
        password: await encryptPassword("admin1234"),
        rol: "administrador",
      });
      await userRepository.save(user1);
      console.log("* => Usuario creado exitosamente");
    } else {
      user1 = await userRepository.findOneBy({
        email: "usuario1@alumnos.ubiobio.cl",
      });
    }

    // Crear Vehículos
    const vehiculoRepository = AppDataSource.getRepository(Vehiculo);
    const vehiculoCount = await vehiculoRepository.count();
    if (vehiculoCount === 0 && user1) {
      await Promise.all([
        vehiculoRepository.save(
          vehiculoRepository.create({
            patente: "ABCD12",
            modelo: "Toyota Corolla",
            color: "Gris",
            nro_asientos: 5,
            documentacion: "Permiso de circulación vigente",
            propietario: user1,
          })
        ),
        vehiculoRepository.save(
          vehiculoRepository.create({
            patente: "EFGH34",
            modelo: "Hyundai Accent",
            color: "Rojo",
            nro_asientos: 4,
            documentacion: "Seguro obligatorio al día",
            propietario: user1,
          })
        ),
      ]);
      console.log("* => Vehículos creados exitosamente");
    }

  } catch (error) {
    console.error("❌ Error al crear datos iniciales:", error);
  }
}

export { createInitialData };
