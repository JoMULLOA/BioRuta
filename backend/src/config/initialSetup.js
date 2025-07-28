"use strict";
import User from "../entity/user.entity.js";
import Vehiculo from "../entity/vehiculo.entity.js";
import Viaje from "../entity/viaje.entity.js";
import Amistad from "../entity/amistad.entity.js";
import Reporte from "../entity/reporte.entity.js";
import TarjetaSandbox from "../entity/tarjetaSandbox.entity.js";
import { AppDataSource } from "./configDb.js";
import { encryptPassword } from "../helpers/bcrypt.helper.js";

// Función para calcular dígito verificador del RUT
function calcularDV(rut) {
  let suma = 0;
  let multiplicador = 2;
  
  // Calcular desde derecha a izquierda
  while (rut > 0) {
    suma += (rut % 10) * multiplicador;
    rut = Math.floor(rut / 10);
    multiplicador = multiplicador < 7 ? multiplicador + 1 : 2;
  }
  
  const resto = suma % 11;
  const dv = 11 - resto;
  
  if (dv === 11) return '0';
  if (dv === 10) return 'K';
  return dv.toString();
}

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
        saldo: 100000,
        tarjetas: []
      });
      await userRepository.save(user1);
      console.log("* => Usuario 1 creado exitosamente (Saldo inicial: $100,000)");

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
        saldo: 100000,
        tarjetas: []
      });
      await userRepository.save(user2);
      console.log("* => Usuario 2 creado exitosamente (Saldo inicial: $100,000)");

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
        saldo: 100000,
        tarjetas: []
      });
      await userRepository.save(user3);
      console.log("* => Usuario 3 creado exitosamente (Saldo inicial: $100,000)");

      // =============== CREAR 97 USUARIOS ADICIONALES ===============
      console.log("🔄 Creando 97 usuarios adicionales...");
      
      const carreras = [
        "Ingeniería Civil en Informática", "Ingeniería Comercial", "Medicina", 
        "Psicología", "Derecho", "Arquitectura", "Ingeniería Civil Industrial",
        "Enfermería", "Pedagogía en Educación Básica", "Contador Auditor",
        "Trabajo Social", "Kinesiología", "Periodismo", "Diseño Gráfico",
        "Ingeniería en Construcción", "Veterinaria", "Química y Farmacia",
        "Fonoaudiología", "Ingeniería Civil", "Pedagogía en Inglés",
        "Nutrición y Dietética", "Ingeniería Ambiental", "Biotecnología",
        "Odontología", "Terapia Ocupacional", "Ingeniería Forestal",
        "Pedagogía en Matemáticas", "Administración Pública", "Sociología",
        "Ingeniería en Alimentos"
      ];

      const generos = ["masculino", "femenino"];
      const clasificaciones = [1, 2, 3];
      
      const usuarios = [];
      
      for (let i = 4; i <= 100; i++) {
        // Generar RUT aleatorio válido
        const rutNum = Math.floor(Math.random() * (29999999 - 10000000) + 10000000);
        const dv = calcularDV(rutNum);
        const rut = `${rutNum.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")}-${dv}`;
        
        // Generar fecha de nacimiento aleatoria (18-30 años)
        const añoActual = 2025;
        const añoNacimiento = añoActual - Math.floor(Math.random() * (30 - 18 + 1) + 18);
        const mes = Math.floor(Math.random() * 12) + 1;
        const dia = Math.floor(Math.random() * 28) + 1;
        const fechaNacimiento = `${añoNacimiento}-${mes.toString().padStart(2, '0')}-${dia.toString().padStart(2, '0')}`;
        
        // Selecciones aleatorias
        const carrera = carreras[Math.floor(Math.random() * carreras.length)];
        const genero = generos[Math.floor(Math.random() * generos.length)];
        const clasificacion = clasificaciones[Math.floor(Math.random() * clasificaciones.length)];
        const puntuacion = Math.floor(Math.random() * 5) + 1; // 1-5
        
        const usuario = userRepository.create({
          rut: rut,
          nombreCompleto: `Usuario${i}`,
          email: `usuario${i}@alumnos.ubiobio.cl`,
          password: await encryptPassword("user1234"),
          genero: genero,
          fechaNacimiento: fechaNacimiento,
          rol: "estudiante",
          carrera: carrera,
          puntuacion: puntuacion,
          clasificacion: clasificacion,
          saldo: 100000,
          tarjetas: []
        });
        
        usuarios.push(usuario);
        
        // Guardar en lotes de 10 para mejor rendimiento
        if (usuarios.length === 10 || i === 100) {
          await userRepository.save(usuarios);
          console.log(`   ✅ Usuarios ${i - usuarios.length + 1} al ${i} creados`);
          usuarios.length = 0; // Limpiar array
        }
      }
      
      console.log("✅ 97 usuarios adicionales creados exitosamente");
      console.log("📊 Total de usuarios: 100 estudiantes + 1 administrador");

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

    // Crear Vehículos para TODOS los usuarios
    const vehiculoRepository = AppDataSource.getRepository(Vehiculo);
    const vehiculoCount = await vehiculoRepository.count();
    
    if (vehiculoCount === 0) {
      console.log("🚗 Creando vehículos para todos los usuarios...");
      
      // Obtener todos los usuarios estudiantes (incluyendo user1, user2, user3)
      const todosLosUsuarios = await userRepository.find({
        where: { rol: "estudiante" }
      });
      
      // Asegurar que user1, user2 y user3 estén incluidos si existen
      const usuariosBase = [user1, user2, user3].filter(u => u !== null);
      
      // Combinar usuarios base con el resto, evitando duplicados
      const usuariosParaVehiculos = [...usuariosBase];
      for (const usuario of todosLosUsuarios) {
        if (!usuariosParaVehiculos.find(u => u.rut === usuario.rut)) {
          usuariosParaVehiculos.push(usuario);
        }
      }
      
      const marcas = ["Toyota", "Hyundai", "Ford", "Chevrolet", "Nissan", "Volkswagen", "Kia", "Mazda", "Honda", "Suzuki"];
      const modelos = {
        "Toyota": ["Corolla", "Yaris", "RAV4", "Camry", "Prius"],
        "Hyundai": ["Accent", "Elantra", "Tucson", "i10", "i20"],
        "Ford": ["Fiesta", "Focus", "Escape", "EcoSport", "Ka"],
        "Chevrolet": ["Spark", "Sonic", "Cruze", "Tracker", "Onix"],
        "Nissan": ["March", "Versa", "Sentra", "X-Trail", "Kicks"],
        "Volkswagen": ["Gol", "Polo", "Jetta", "Tiguan", "T-Cross"],
        "Kia": ["Rio", "Cerato", "Sportage", "Picanto", "Stonic"],
        "Mazda": ["2", "3", "CX-3", "CX-5", "6"],
        "Honda": ["City", "Civic", "CR-V", "HR-V", "Fit"],
        "Suzuki": ["Swift", "Baleno", "Vitara", "Jimny", "Alto"]
      };
      
      const colores = ["Blanco", "Negro", "Gris", "Plata", "Rojo", "Azul", "Verde", "Amarillo", "Naranja", "Morado"];
      const tiposCombustible = ["bencina", "petroleo", "electrico", "hibrido"];
      const años = [2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024];
      
      const vehiculos = [];
      
      for (let i = 0; i < usuariosParaVehiculos.length; i++) {
        const usuario = usuariosParaVehiculos[i];
        const marca = marcas[i % marcas.length];
        const modelo = modelos[marca][i % modelos[marca].length];
        const color = colores[i % colores.length];
        const año = años[i % años.length];
        const tipoCombustible = tiposCombustible[i % tiposCombustible.length];
        const nroAsientos = Math.floor(Math.random() * 3) + 4; // 4-6 asientos
        
        // Generar patente única (formato chileno: ABCD12 o AB1234)
        const letras = String.fromCharCode(65 + (i % 26)) + String.fromCharCode(65 + ((i + 1) % 26));
        const numeros = String(1000 + (i % 9000)).padStart(4, '0');
        const patente = i % 2 === 0 ? `${letras}${letras.charAt(0)}${letras.charAt(1)}${numeros.slice(0, 2)}` : `${letras}${numeros}`;
        
        const vehiculo = vehiculoRepository.create({
          patente: patente,
          tipo: "Auto",
          marca: marca,
          modelo: `${marca} ${modelo}`,
          año: año,
          color: color,
          nro_asientos: nroAsientos,
          tipoCombustible: tipoCombustible,
          documentacion: "Permiso de circulación vigente y seguro obligatorio",
          propietario: usuario,
        });
        
        vehiculos.push(vehiculo);
        
        // Guardar en lotes de 20 para mejor rendimiento
        if (vehiculos.length === 20 || i === usuariosParaVehiculos.length - 1) {
          await vehiculoRepository.save(vehiculos);
          console.log(`   🚙 Vehículos ${i - vehiculos.length + 2} al ${i + 1} creados`);
          vehiculos.length = 0; // Limpiar array
        }
      }
      
      console.log(`✅ Se crearon ${usuariosParaVehiculos.length} vehículos exitosamente (uno por usuario)`);
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
    const userRepository = AppDataSource.getRepository(User);
    const todosLosUsuarios = await userRepository.find({
      where: { rol: "estudiante" }
    });

    console.log("🃏 Asignando tarjetas a usuarios...");
    
    const bancos = [
      "Banco de Chile", "BancoEstado", "Santander", "BCI", "Banco Falabella",
      "Banco Ripley", "Banco Security", "Banco Consorcio", "Banco Itaú",
      "Banco de Crédito e Inversiones", "Banco Paris", "Banco Bice"
    ];

    // =============== ASIGNAR TARJETAS A TODOS LOS USUARIOS ===============
    console.log("🎯 Creando y asignando tarjetas específicas para todos los usuarios...");
    
    const usuariosConTarjetas = [];
    
    for (let i = 0; i < todosLosUsuarios.length; i++) {
      const usuario = todosLosUsuarios[i];
      
      // Determinar tipo de tarjeta basado en el número de usuario
      let tipo, numeroBase;
      if (i % 3 === 0) {
        tipo = "visa";
        numeroBase = "4" + String(Math.floor(Math.random() * 999999999999999)).padStart(15, '0');
      } else if (i % 3 === 1) {
        tipo = "mastercard";
        numeroBase = "5" + String(Math.floor(Math.random() * 999999999999999)).padStart(15, '0');
      } else {
        tipo = "american_express";
        numeroBase = "3" + String(Math.floor(Math.random() * 99999999999999)).padStart(14, '0');
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
      const limites = [100000, 200000, 300000, 500000, 750000, 1000000];
      const limiteCredito = limites[i % limites.length];
      
      const banco = bancos[i % bancos.length];

      // Crear objeto tarjeta para el usuario
      const tarjeta = {
        id: `tarjeta_${i + 1}`,
        numero: numeroFormateado,
        nombreTitular: usuario.nombreCompleto,
        fechaVencimiento,
        cvv,
        tipo,
        banco,
        limiteCredito,
        activa: true,
        fechaCreacion: new Date().toISOString()
      };

      // Asignar tarjeta al usuario
      usuario.tarjetas = [tarjeta];
      usuariosConTarjetas.push(usuario);
      
      // Guardar en lotes de 25 para mejor rendimiento
      if (usuariosConTarjetas.length === 25 || i === todosLosUsuarios.length - 1) {
        await userRepository.save(usuariosConTarjetas);
        console.log(`   💳 Tarjetas asignadas a usuarios ${i - usuariosConTarjetas.length + 2} al ${i + 1}`);
        usuariosConTarjetas.length = 0; // Limpiar array
      }
    }

    console.log(`✅ Se asignaron ${todosLosUsuarios.length} tarjetas exitosamente`);
    console.log(`   💳 Una tarjeta por cada usuario estudiante`);
    
  } catch (error) {
    console.error("❌ Error al asignar tarjetas a usuarios:", error);
  }
}

export { createInitialData };
