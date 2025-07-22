"use strict";
import User from "../entity/user.entity.js";
import Vehiculo from "../entity/vehiculo.entity.js";
import Viaje from "../entity/viaje.entity.js";
import Amistad from "../entity/amistad.entity.js";
import Reporte from "../entity/reporte.entity.js";
import TarjetaSandbox from "../entity/tarjetaSandbox.entity.js";
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
        saldo: 25000,
        tarjetas: []
      });
      await userRepository.save(user1);
      console.log("* => Usuario 1 creado exitosamente (Saldo inicial: $25,000)");

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
        saldo: 25000,
        tarjetas: []
      });
      await userRepository.save(user2);
      console.log("* => Usuario 2 creado exitosamente (Saldo inicial: $25,000)");

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
        saldo: 25000,
        tarjetas: []
      });
      await userRepository.save(user3);
      console.log("* => Usuario 3 creado exitosamente (Saldo inicial: $25,000)");

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

    // Crear reportes iniciales
    await createInitialReports();

    // Crear tarjetas de sandbox para pruebas de pagos
    await createSandboxCards();

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

    // Configurar reportes de prueba (opcional)
    await createInitialReports();
  } catch (error) {
    console.error("❌ Error al crear índices de MongoDB:", error);
  }
}

async function createInitialReports() {
  try {
    const reporteRepository = AppDataSource.getRepository(Reporte);
    const reporteCount = await reporteRepository.count();
    
    if (reporteCount === 0) {
      console.log("* => Creando reportes de ejemplo...");
      
      // No crear reportes de ejemplo por defecto
      // Solo configurar la estructura
      console.log("* => Sistema de reportes configurado correctamente");
    } else {
      console.log("* => Sistema de reportes ya configurado");
    }
  } catch (error) {
    console.error("❌ Error al configurar sistema de reportes:", error);
  }
}

// Función para crear tarjetas de sandbox para pruebas
async function createSandboxCards() {
  try {
    const tarjetaRepository = AppDataSource.getRepository(TarjetaSandbox);
    const tarjetaCount = await tarjetaRepository.count();

    if (tarjetaCount === 0) {
      console.log("🃏 Creando tarjetas de sandbox...");
      
      const bancos = [
        "Banco de Chile", "BancoEstado", "Santander", "BCI", "Banco Falabella",
        "Banco Ripley", "Banco Security", "Banco Consorcio", "Banco Itaú",
        "Banco de Crédito e Inversiones", "Banco Paris", "Banco Bice"
      ];

      const nombres = [
        "Juan Pérez", "María González", "Carlos Rodríguez", "Ana Martínez", "Luis López",
        "Carmen Silva", "Pedro Morales", "Laura Hernández", "Diego Torres", "Sofía Ruiz",
        "Andrés Castro", "Valentina Muñoz", "Gabriel Ortega", "Isabella Vargas", "Matías Rojas",
        "Camila Soto", "Benjamín Núñez", "Antonia Flores", "Sebastián Contreras", "Francisca Reyes",
        "Nicolás Garrido", "Javiera Mendoza", "Tomás Espinoza", "Constanza Aguilar", "Felipe Pizarro",
        "Martina Campos", "Ignacio Guerrero", "Catalina Vega", "Vicente Maldonado", "Esperanza León"
      ];

      const tarjetas = [];

      // =============== TARJETAS ESPECÍFICAS PARA USUARIOS DE PRUEBA ===============
      console.log("🎯 Creando tarjetas específicas para usuarios de prueba...");
      
      // Tarjeta para Usuario1 - VISA
      tarjetas.push({
        numero: "4111-1111-1111-1111",
        nombreTitular: "Usuario1",
        fechaVencimiento: "12/2028",
        cvv: "123",
        tipo: "visa",
        banco: "Banco de Chile",
        limiteCredito: 500000,
        activa: true
      });
      
      // Tarjeta para Usuario2 - MASTERCARD
      tarjetas.push({
        numero: "5555-5555-5555-4444",
        nombreTitular: "Usuario2", 
        fechaVencimiento: "06/2029",
        cvv: "456",
        tipo: "mastercard",
        banco: "Santander",
        limiteCredito: 300000,
        activa: true
      });
      
      // Tarjeta para Usuario3 - AMERICAN EXPRESS
      tarjetas.push({
        numero: "3782-8224-6310-005",
        nombreTitular: "Usuario3",
        fechaVencimiento: "09/2027", 
        cvv: "7890",
        tipo: "american_express",
        banco: "BCI",
        limiteCredito: 750000,
        activa: true
      });

      console.log("✅ Tarjetas específicas creadas:");
      console.log("   📧 Usuario1: 4111-1111-1111-1111 | CVV: 123 | Exp: 12/2028");
      console.log("   📧 Usuario2: 5555-5555-5555-4444 | CVV: 456 | Exp: 06/2029"); 
      console.log("   📧 Usuario3: 3782-8224-6310-005  | CVV: 7890 | Exp: 09/2027");

      // =============== GENERAR 100 TARJETAS ALEATORIAS ADICIONALES ===============
      console.log("🎲 Generando 100 tarjetas aleatorias adicionales...");
      
      for (let i = 0; i < 100; i++) {
        const tipo = ["visa", "mastercard", "american_express"][i % 3];
        const banco = bancos[i % bancos.length];
        const nombre = nombres[i % nombres.length];
        
        // Generar número de tarjeta ficticio
        let numeroBase;
        switch (tipo) {
          case "visa":
            numeroBase = "4" + String(Math.floor(Math.random() * 999999999999999)).padStart(15, '0');
            break;
          case "mastercard":
            numeroBase = "5" + String(Math.floor(Math.random() * 999999999999999)).padStart(15, '0');
            break;
          case "american_express":
            numeroBase = "3" + String(Math.floor(Math.random() * 99999999999999)).padStart(14, '0');
            break;
        }
        
        // Formatear número de tarjeta
        const numeroFormateado = numeroBase.replace(/(.{4})/g, '$1-').slice(0, -1);
        
        // Generar fecha de vencimiento (entre 2025 y 2030)
        const año = 2025 + (i % 6);
        const mes = (i % 12) + 1;
        const fechaVencimiento = `${mes.toString().padStart(2, '0')}/${año}`;
        
        // Generar CVV
        const cvv = tipo === "american_express" 
          ? String(Math.floor(Math.random() * 9999)).padStart(4, '0')
          : String(Math.floor(Math.random() * 999)).padStart(3, '0');
        
        // Límite de crédito aleatorio
        const limites = [50000, 100000, 200000, 300000, 500000, 750000, 1000000];
        const limiteCredito = limites[i % limites.length];

        tarjetas.push({
          numero: numeroFormateado,
          nombreTitular: nombre,
          fechaVencimiento,
          cvv,
          tipo,
          banco,
          limiteCredito,
          activa: true
        });
      }

      // Guardar todas las tarjetas
      await tarjetaRepository.save(tarjetas);
      console.log(`✅ Se crearon ${tarjetas.length} tarjetas de sandbox exitosamente`);
      console.log(`   🎯 3 tarjetas específicas para usuarios de prueba`);
      console.log(`   🎲 ${tarjetas.length - 3} tarjetas aleatorias adicionales`);
      
    } else {
      console.log("* => Tarjetas de sandbox ya configuradas");
    }
  } catch (error) {
    console.error("❌ Error al crear tarjetas de sandbox:", error);
  }
}

export { createInitialData };
