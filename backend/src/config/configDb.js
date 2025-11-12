"use strict";
import { DataSource } from "typeorm";
import { DATABASE, DB_USERNAME, HOST, PASSWORD } from "./configEnv.js";

export const AppDataSource = new DataSource({
  type: "postgres",
  host: `${HOST}`,
  port: 5432,
  username: `${DB_USERNAME}`,
  password: `${PASSWORD}`,
  database: `${DATABASE}`,
  entities: ["src/entity/**/*.js"],
  synchronize: true, // Activado para crear las tablas automáticamente
  dropSchema: true, // Elimina el esquema antes de crear las tablas (solo usar cuando hay conflictos)
  logging: false,
});

export async function connectDB() {
  try {
    await AppDataSource.initialize();
    console.log("=> Conexión exitosa a la base de datos!");
    
    // Esperar explícitamente a que TypeORM termine de sincronizar
    if (AppDataSource.isInitialized) {
      console.log("=> Sincronización de esquema completada");
      
      // Pequeña espera adicional para asegurar que las tablas estén listas
      await new Promise(resolve => setTimeout(resolve, 1000));
      console.log("=> Base de datos lista para operaciones");
    }
  } catch (error) {
    console.error("Error al conectar con la base de datos:", error);
    process.exit(1);
  }
}