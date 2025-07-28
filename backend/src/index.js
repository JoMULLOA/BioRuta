"use strict";
import cors from "cors";
import morgan from "morgan";
import cookieParser from "cookie-parser";
import session from "express-session";
import passport from "passport";
import express, { json, urlencoded } from "express";
import cron from "node-cron";
import http from "http";
import 'dotenv/config';
import mongoose from "mongoose";
import userRoutes from "./routes/user.routes.js";
import chatRoutes from "./routes/chat.routes.js";
import viajeRoutes from "./routes/viaje.routes.js";
import indexRoutes from "./routes/index.routes.js";
import pingRoutes from "./routes/ping.routes.js";
import estadisticasRoutes from "./routes/estadisticas.routes.js";
import reporteRoutes from "./routes/reporte.routes.js";
import { connectMongoDB } from "./config/mongooseClient.js";
import { initSocket, getSocketInstance } from "./socket.js"; 
import { cookieKey, HOST, PORT } from "./config/configEnv.js";
import { connectDB } from "./config/configDb.js";
import { createInitialData } from "./config/initialSetup.js";
import { passportJwtSetup } from "./auth/passport.auth.js";
import ViajeMonitoringService from "./services/viaje.monitoring.service.js";



async function setupServer() {
  try {
    const app = express();

    app.disable("x-powered-by");

    // Middleware de configuración
    app.use(cors({
      credentials: true,
      origin: true,
    }));

    app.use(urlencoded({
      extended: true,
      limit: "1mb",
    }));

    app.use(json({
      limit: "1mb",
    }));

    app.use(cookieParser());
    app.use(morgan("dev"));

    app.use(session({
      secret: cookieKey,
      resave: false,
      saveUninitialized: false,
      cookie: {
        secure: false,
        httpOnly: true,
        sameSite: "strict",
      },
    }));

    // Inicialización de Passport para autenticación
    app.use(passport.initialize());
    app.use(passport.session());
    
    // Registro de rutas
    app.use("/api", indexRoutes);
    app.use("/api/users", userRoutes); // Rutas de usuarios, que incluye /api/users/garzones
    app.use("/api/chat", chatRoutes); // Rutas de chat
    app.use("/api/viajes", viajeRoutes); // Rutas de viajes
    app.use("/api", pingRoutes);  // Rutas de MongoDB
    app.use("/api/estadisticas", estadisticasRoutes); // Rutas de estadísticas
    app.use("/api/reportes", reporteRoutes); // Rutas de reportes

    const server = http.createServer(app);
    initSocket(server); // Inicializa Socket.IO con el servidor
    
    // Hacer que la instancia de Socket.io esté disponible en los controladores
    app.set('io', getSocketInstance());
    
    // Inicio del servidor usando server.listen() para incluir Socket.IO
    server.listen(PORT, '0.0.0.0', () => {
      console.log(`✅ Servidor corriendo en ${HOST}:${PORT}/api`);
      console.log(`🌐 Accesible desde emulador Android en 10.0.2.2:${PORT}/api`);
      console.log(`🔌 Socket.IO disponible en ${HOST}:${PORT}/socket.io/`);
      
      // Iniciar el monitoreo automático de viajes
      ViajeMonitoringService.start();
    });
  } catch (error) {
    console.error("Error en index.js -> setupServer():", error);
  }
}

async function setupAPI() {
  try {
    await connectDB();            // Postgres 
    await connectMongoDB();      // Mongo Atlas
    
    // Configurar Passport después de que la base de datos esté conectada
    passportJwtSetup();
    
    await setupServer();
    await createInitialData();
  } catch (error) {
    console.error("Error en index.js -> setupAPI():", error);
  }
}

setupAPI()
  .then(() => console.log("=> API Iniciada exitosamente"))
  .catch((error) => console.error("Error al iniciar la API:", error));