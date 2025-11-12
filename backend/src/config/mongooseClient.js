import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config();

export async function connectMongoDB() {
  try {
    const mongoUri = process.env.MONGO_URI;
    console.log("🧪 Intentando conectar a MongoDB...");
    
    await mongoose.connect(mongoUri, {
      serverSelectionTimeoutMS: 5000, // Timeout de 5 segundos
      socketTimeoutMS: 45000, // Timeout de socket
    });
    
    console.log("✅ MongoDB conectado exitosamente");
    console.log(`📍 Conectado a: ${mongoUri.split('@')[1]?.split('?')[0] || 'MongoDB'}`);
  } catch (err) {
    console.error("❌ Error conectando a MongoDB:", err.message);
    console.error("⚠️  La aplicación continuará sin MongoDB");
    console.error("💡 Verifica:");
    console.error("   1. Tu conexión a internet");
    console.error("   2. Whitelist de IP en MongoDB Atlas");
    console.error("   3. Credenciales correctas en .env");
  }
}