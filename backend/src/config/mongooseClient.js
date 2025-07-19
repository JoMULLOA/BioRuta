import mongoose from "mongoose";
import { config, environment } from "./environment.js";

export async function connectMongoDB() {
  try {
    // 🌍 Usa la configuración según el entorno
    const mongoUri = config.database.mongodb;
    
    console.log(`🗄️  Conectando a MongoDB en entorno: ${environment.toUpperCase()}`);
    console.log(`🔗 URI: ${mongoUri.replace(/\/\/.*:.*@/, '//***:***@')}`); // Oculta credenciales
    
    await mongoose.connect(mongoUri, config.database.options);
    
    console.log("✅ MongoDB conectado exitosamente");
  } catch (err) {
    console.error("❌ Error conectando a MongoDB:", err.message);
    throw err;
  }
}