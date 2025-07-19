import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config();

export async function connectMongoDB() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log("🧪 Conectando a:", process.env.MONGO_URI);

    console.log("✅ Mongo Atlas conectado");
  } catch (err) {
    console.error("❌ Error conectando a MongoDB:", err.message);
  }
}