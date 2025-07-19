"use strict";
import User from "../entity/user.entity.js";
import Vehiculo from "../entity/vehiculo.entity.js";
import Viaje from "../entity/viaje.entity.js";
import Amistad from "../entity/amistad.entity.js";
import { AppDataSource } from "./configDb.js";
import { encryptPassword } from "../helpers/bcrypt.helper.js";
//Los ruts estan hasta un maximo de 29.999.999-9, por lo que no se pueden crear usuarios con ruts mayores a ese valor, se creara, 
//pero no se podra buscar como un amigo.
async function createInitialData() {
  try {
    // Crear Usuarios
    const userRepository = AppDataSource.getRepository(User);
    const userCount = await userRepository.count();
    let user1 = null;
    let user2 = null;
    let user3 = null;

    if (userCount === 0) {
      
      user1 = userRepository.create({
        rut: "22.333.111-4",
        nombreCompleto: "Usuario1",
        email: "usuario1@alumnos.ubiobio.cl",
        password: await encryptPassword("admin1234"),
        genero: "masculino",
        fechaNacimiento: "2000-01-01",
        rol: "estudiante",
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
        genero: "femenino",
        fechaNacimiento: "2001-02-02",
        rol: "estudiante",
        puntuacion: 3,
        clasificacion : 1,
      });
      await userRepository.save(user2);
      console.log("* => Usuario 2 creado exitosamente");

      user3 = userRepository.create({
        rut: "23.444.555-6",
        nombreCompleto: "Usuario3",
        email: "usuario3@alumnos.ubiobio.cl",
        password: await encryptPassword("user3456"),
        genero: "masculino",
        fechaNacimiento: "2002-03-03",
        rol: "estudiante",
        puntuacion: 4,
        clasificacion : 2,
      });
      await userRepository.save(user3);
      console.log("* => Usuario 3 creado exitosamente");

      // Crear un usuario administrador
      const adminUser = userRepository.create({
        rut: "20.444.555-6",
        nombreCompleto: "Administrador",
        email: "admin@ubiobio.cl",
        password: await encryptPassword("admin1234"),
        genero: "prefiero_no_decir",
        fechaNacimiento: "1990-01-01",
        rol: "administrador",
      });
      await userRepository.save(adminUser);
      console.log("* => Usuario administrador creado exitosamente");

    } else {
      user1 = await userRepository.findOneBy({
        email: "usuario1@alumnos.ubiobio.cl",
      });
      user2 = await userRepository.findOneBy({
        email: "usuario2@alumnos.ubiobio.cl",
      });
      user3 = await userRepository.findOneBy({
        email: "usuario3@alumnos.ubiobio.cl",
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
            tipo: "Auto",
            marca: "Toyota",
            modelo: "Toyota Corolla",
            año: 2020,
            color: "Gris",
            nro_asientos: 5,
            documentacion: "Permiso de circulación vigente",
            propietario: user1,
          })
        );
        await vehiculoRepository.save(
          vehiculoRepository.create({
            patente: "EFGH34",
            tipo: "Auto",
            marca: "Hyundai",
            modelo: "Hyundai Accent",
            año: 2018,
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
            tipo: "Auto",
            marca: "Ford",
            modelo: "Ford Fiesta",
            año: 2019,
            color: "Azul",
            nro_asientos: 4,
            documentacion: "Permiso de circulación vigente",
            propietario: user2,
          })
        );
      }
      console.log("* => Vehículos creados exitosamente");
    }

    // Crear amistades de prueba usando la entidad Amistad
    const amistadRepository = AppDataSource.getRepository(Amistad);
    const amistadCount = await amistadRepository.count();
    
    if (amistadCount === 0 && user1 && user2 && user3) {
      // Crear amistad entre Usuario1 y Usuario2
      const amistad1 = amistadRepository.create({
        rutUsuario1: user1.rut,
        rutUsuario2: user2.rut,
        fechaAmistad: new Date(),
        bloqueado: false,
        usuario1: user1,
        usuario2: user2
      });
      await amistadRepository.save(amistad1);
      
      console.log("* => Amistades de prueba creadas exitosamente");
      console.log("  - Usuario1 es amigo de Usuario2");
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
