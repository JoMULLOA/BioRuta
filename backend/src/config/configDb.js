"use strict";
import { DataSource } from "typeorm";
import { DATABASE, DB_USERNAME, HOST, PASSWORD } from "./configEnv.js";
import { config, environment } from "./environment.js";

export const AppDataSource = new DataSource({
  type: "postgres",
  host: `${HOST}`,
  port: 5432,
  username: `${DB_USERNAME}`,
  password: `${PASSWORD}`,
  database: `${DATABASE}`,
  entities: ["src/entity/**/*.js"],
  synchronize: environment !== 'production', // Solo en desarrollo y test
  dropSchema: environment === 'development', // Solo en desarrollo
  logging: config.logging.requests,
});

export async function connectDB() {
  try {
    console.log(`🔗 Conectando a PostgreSQL en entorno: ${environment.toUpperCase()}`);
    console.log(`🏠 Host: ${HOST}:5432`);
    console.log(`🗄️  Database: ${DATABASE}`);
    console.log(`👤 User: ${DB_USERNAME}`);
    
    await AppDataSource.initialize();
    console.log("✅ PostgreSQL conectado exitosamente!");
  } catch (error) {
    console.error("❌ Error al conectar con PostgreSQL:", error.message);
    throw error;
  }
}