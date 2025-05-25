import User from "../entity/user.entity.js";
import { AppDataSource } from "./configDb.js";
import { encryptPassword } from "../helpers/bcrypt.helper.js";

async function createInitialData() {
  try {
    // Crear Usuarios
    const userRepository = AppDataSource.getRepository(User);
    const userCount = await userRepository.count();
    if (userCount === 0) {
      await Promise.all([
        userRepository.save(
          userRepository.create({
            nombreCompleto: "Usuario1",
            rut: "22.333.111-4",
            email: "usuario1@alumnos.ubiobio.cl",
            password: await encryptPassword("admin1234"),
            rol: "administrador",
          })
        ),
      ]);
      console.log("* => Usuarios creados exitosamente");
    }

  } catch (error) {
    console.error("Error al crear datos iniciales:", error);
  }
}

export { createInitialData };