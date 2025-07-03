"use strict";
import User from "../entity/user.entity.js";
import Vehiculo from "../entity/vehiculo.entity.js";
import Viaje from "../entity/viaje.entity.js";
import { AppDataSource } from "./configDb.js";
import { encryptPassword } from "../helpers/bcrypt.helper.js";

async function createInitialData() {
  try {
    // Crear Usuarios
    const userRepository = AppDataSource.getRepository(User);
    const userCount = await userRepository.count();
    let user1 = null;
    let user2 = null;

    if (userCount === 0) {
      
      user1 = userRepository.create({
        rut: "22.333.111-4",
        nombreCompleto: "Usuario1",
        email: "usuario1@alumnos.ubiobio.cl",
        password: await encryptPassword("admin1234"),
        rol: "administrador",
        puntuacion: 5,
        clasificacion : 2,
      });
      await userRepository.save(user1);
      console.log("* => Usuario 1 creado exitosamente");

      user2 = userRepository.create({
        rut: "11.222.333-5",
        nombreCompleto: "Usuario2",
        email: "usuario2@alumnos.ubiobio.cl",
        password: await encryptPassword("user2345"),
        rol: "usuario",
        puntuacion: 3,
        clasificacion : 1,
      });
      await userRepository.save(user2);
      console.log("* => Usuario 2 creado exitosamente");
    } else {
      user1 = await userRepository.findOneBy({
        email: "usuario1@alumnos.ubiobio.cl",
      });
      user2 = await userRepository.findOneBy({
        email: "usuario2@alumnos.ubiobio.cl",
      });
    }

    // Crear Vehículos
    const vehiculoRepository = AppDataSource.getRepository(Vehiculo);
    const vehiculoCount = await vehiculoRepository.count();
    if (vehiculoCount === 0) {
      if (user1) {
        await vehiculoRepository.save(
          vehiculoRepository.create({
            patente: "ABCD12",
            modelo: "Toyota Corolla",
            color: "Gris",
            nro_asientos: 5,
            documentacion: "Permiso de circulación vigente",
            propietario: user1,
          })
        );
        await vehiculoRepository.save(
          vehiculoRepository.create({
            patente: "EFGH34",
            modelo: "Hyundai Accent",
            color: "Rojo",
            nro_asientos: 4,
            documentacion: "Seguro obligatorio al día",
            propietario: user1,
          })
        );
      }
      if (user2) {
        await vehiculoRepository.save(
          vehiculoRepository.create({
            patente: "IJKL56",
            modelo: "Ford Fiesta",
            color: "Azul",
            nro_asientos: 4,
            documentacion: "Permiso de circulación vigente",
            propietario: user2,
          })
        );
      }
      console.log("* => Vehículos creados exitosamente");
    }

    // Crear índices geoespaciales para MongoDB
    await createMongoIndexes();

  } catch (error) {
    console.error("❌ Error al crear datos iniciales:", error);
  }
}

async function createMongoIndexes() {
  try {
    // Verificar si los índices ya existen
    const collection = Viaje.collection;
    const indexes = await collection.listIndexes().toArray();
    
    // Verificar y crear el índice de origen
    const hasGeoIndexOrigen = indexes.some(index => 
      Object.keys(index.key).includes('origen.ubicacion') && 
      Object.values(index.key).includes('2dsphere')
    );

    if (!hasGeoIndexOrigen) {
      await collection.createIndex(
        { "origen.ubicacion": "2dsphere" },
        { name: "origen_ubicacion_2dsphere", background: true }
      );
      console.log("* => Índice geoespacial de origen creado");
    } else {
      console.log("* => Índice geoespacial de origen ya existe");
    }

    // Verificar y crear el índice de destino (necesario para publicar viajes)
    const hasGeoIndexDestino = indexes.some(index => 
      Object.keys(index.key).includes('destino.ubicacion') && 
      Object.values(index.key).includes('2dsphere')
    );

    if (!hasGeoIndexDestino) {
      await collection.createIndex(
        { "destino.ubicacion": "2dsphere" },
        { name: "destino_ubicacion_2dsphere", background: true }
      );
      console.log("* => Índice geoespacial de destino creado");
    } else {
      console.log("* => Índice geoespacial de destino ya existe");
    }

    // Crear otros índices importantes
    await collection.createIndex({ fecha_ida: 1 });
    await collection.createIndex({ estado: 1 });
    await collection.createIndex({ usuario_rut: 1 });
    await collection.createIndex({ vehiculo_patente: 1 });

    console.log("* => Índices de MongoDB creados exitosamente");
  } catch (error) {
    console.error("❌ Error al crear índices de MongoDB:", error);
  }
}

export { createInitialData };
