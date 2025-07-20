"use strict";
import mongoose from "mongoose";
import dotenv from "dotenv";

// Cargar variables de entorno
dotenv.config();

// Configurar conexión a MongoDB
const MONGODB_URI = process.env.MONGO_URI; // Usar MONGO_URI en lugar de MONGODB_URI

if (!MONGODB_URI) {
  console.error("❌ Error: MONGO_URI no está definida en las variables de entorno");
  process.exit(1);
}

async function removeHoraFields() {
  try {
    console.log("🔗 Conectando a MongoDB...");
    await mongoose.connect(MONGODB_URI);
    console.log("✅ Conectado a MongoDB");

    // Obtener la colección de viajes
    const db = mongoose.connection.db;
    const viajesCollection = db.collection('viajes');

    console.log("🔍 Buscando documentos con campos hora_ida o hora_vuelta...");
    
    // Contar documentos que tienen estos campos
    const countWithHoraFields = await viajesCollection.countDocuments({
      $or: [
        { hora_ida: { $exists: true } },
        { hora_vuelta: { $exists: true } }
      ]
    });

    console.log(`📊 Encontrados ${countWithHoraFields} documentos con campos de hora`);

    if (countWithHoraFields === 0) {
      console.log("✅ No hay documentos que necesiten migración");
      return;
    }

    // Mostrar algunos ejemplos antes de la migración
    console.log("📄 Ejemplos de documentos antes de la migración:");
    const ejemplos = await viajesCollection.find({
      $or: [
        { hora_ida: { $exists: true } },
        { hora_vuelta: { $exists: true } }
      ]
    }).limit(3).toArray();

    ejemplos.forEach((doc, index) => {
      console.log(`\n📝 Documento ${index + 1}:`);
      console.log(`   ID: ${doc._id}`);
      console.log(`   fecha_ida: ${doc.fecha_ida}`);
      console.log(`   hora_ida: ${doc.hora_ida}`);
      if (doc.fecha_vuelta) console.log(`   fecha_vuelta: ${doc.fecha_vuelta}`);
      if (doc.hora_vuelta) console.log(`   hora_vuelta: ${doc.hora_vuelta}`);
    });

    console.log("\n🚀 Iniciando migración...");

    // Eliminar los campos hora_ida y hora_vuelta de todos los documentos
    const result = await viajesCollection.updateMany(
      {},
      {
        $unset: {
          hora_ida: "",
          hora_vuelta: ""
        }
      }
    );

    console.log(`✅ Migración completada:`);
    console.log(`   - Documentos encontrados: ${result.matchedCount}`);
    console.log(`   - Documentos actualizados: ${result.modifiedCount}`);

    // Verificar que los campos fueron eliminados
    const remainingDocs = await viajesCollection.countDocuments({
      $or: [
        { hora_ida: { $exists: true } },
        { hora_vuelta: { $exists: true } }
      ]
    });

    if (remainingDocs === 0) {
      console.log("✅ Todos los campos hora_ida y hora_vuelta han sido eliminados correctamente");
    } else {
      console.log(`⚠️ Advertencia: Aún quedan ${remainingDocs} documentos con campos de hora`);
    }

    // Mostrar algunos ejemplos después de la migración
    console.log("\n📄 Ejemplos de documentos después de la migración:");
    const ejemplosDespues = await viajesCollection.find({}).limit(3).toArray();

    ejemplosDespues.forEach((doc, index) => {
      console.log(`\n📝 Documento ${index + 1}:`);
      console.log(`   ID: ${doc._id}`);
      console.log(`   fecha_ida: ${doc.fecha_ida}`);
      console.log(`   hora_ida: ${doc.hora_ida || 'ELIMINADO ✅'}`);
      if (doc.fecha_vuelta) {
        console.log(`   fecha_vuelta: ${doc.fecha_vuelta}`);
        console.log(`   hora_vuelta: ${doc.hora_vuelta || 'ELIMINADO ✅'}`);
      }
    });

    console.log("\n🎉 Migración completada exitosamente");

  } catch (error) {
    console.error("❌ Error durante la migración:", error);
    process.exit(1);
  } finally {
    console.log("🔌 Cerrando conexión...");
    await mongoose.disconnect();
    console.log("✅ Conexión cerrada");
  }
}

// Ejecutar la migración
if (import.meta.url === `file://${process.argv[1]}`) {
  removeHoraFields()
    .then(() => {
      console.log("✨ Script de migración finalizado");
      process.exit(0);
    })
    .catch((error) => {
      console.error("💥 Error fatal en el script de migración:", error);
      process.exit(1);
    });
}

export default removeHoraFields;
