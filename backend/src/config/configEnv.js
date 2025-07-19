"use strict";
import { fileURLToPath } from "url";
import path from "path";
import dotenv from "dotenv";

const _filename = fileURLToPath(import.meta.url);

const _dirname = path.dirname(_filename);

const envFilePath = path.resolve(_dirname, ".env");

// 🌍 Carga el archivo .env correcto según el entorno
function loadEnvironmentFile() {
  // En producción (GitHub Actions), las variables ya están en process.env
  if (process.env.GITHUB_ACTIONS || process.env.NODE_ENV === 'production') {
    console.log('🚀 Ejecutándose en CI/CD - usando variables de entorno del sistema');
    return;
  }
  
  // En desarrollo local, cargar desde archivo
  dotenv.config({ path: envFilePath });
  console.log('🏠 Ejecutándose en desarrollo - cargando desde .env');
}

loadEnvironmentFile();

// Debug: Verificar que las variables se carguen correctamente
console.log("🔧 DEBUG - Variables de entorno cargadas:");
console.log("  - ACCESS_TOKEN_SECRET:", process.env.ACCESS_TOKEN_SECRET ? "✅ Definido" : "❌ No definido");
console.log("  - HOST:", process.env.HOST);
console.log("  - PORT:", process.env.PORT);
console.log("  - Ruta del archivo .env:", envFilePath);

export const PORT = process.env.PORT;
export const HOST = process.env.HOST;
export const DB_USERNAME = process.env.DB_USERNAME;
export const PASSWORD = process.env.PASSWORD;
export const DATABASE = process.env.DATABASE;
export const ACCESS_TOKEN_SECRET = process.env.ACCESS_TOKEN_SECRET;
export const cookieKey = process.env.cookieKey;
export const MONGO_URI = process.env.MONGO_URI;