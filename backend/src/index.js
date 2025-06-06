"use strict";
import cors from "cors";
import morgan from "morgan";
import cookieParser from "cookie-parser";
import session from "express-session";
import passport from "passport";
import express, { json, urlencoded } from "express";
import cron from "node-cron";
import { Server as SocketServer } from "socket.io";
import http from "http"; // 👈 Necesario para usar sockets
import 'dotenv/config';

import userRoutes from "./routes/user.routes.js";
import indexRoutes from "./routes/index.routes.js";

import { cookieKey, HOST, PORT } from "./config/configEnv.js";
import { connectDB } from "./config/configDb.js";
import { createInitialData } from "./config/initialSetup.js";
import { passportJwtSetup } from "./auth/passport.auth.js";

// 🧠 Importa tu modelo de mensajes desde Sequelize
import Message from "./entity/message.entity.js"; // Asegúrate que este archivo exista

async function setupServer() {
  try {
    const app = express();
    const server = http.createServer(app); // 👈 Usamos http.Server

    // Socket.IO setup
    const io = new SocketServer(server, {
      cors: {
        origin: "*",
        methods: ["GET", "POST"]
      }
    });

    io.on("connection", (socket) => {
      console.log(`🟢 Usuario conectado: ${socket.id}`);

      socket.on("send_message", async (data) => {
        try {
          const savedMessage = await Message.create({
            sender: data.sender,
            text: data.message,
          });
          io.emit("receive_message", savedMessage); // reenviar a todos
        } catch (err) {
          console.error("❌ Error al guardar mensaje:", err);
        }
      });

      socket.on("disconnect", () => {
        console.log(`🔴 Usuario desconectado: ${socket.id}`);
      });
    });

    // Middleware de configuración
    app.disable("x-powered-by");

    app.use(cors({ credentials: true, origin: true }));
    app.use(urlencoded({ extended: true, limit: "1mb" }));
    app.use(json({ limit: "1mb" }));
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


    app.use(passport.initialize());
    app.use(passport.session());
    passportJwtSetup();

    // Rutas API
    app.use("/api", indexRoutes);
    app.use("/api/users", userRoutes);

    // Iniciar servidor + Socket.IO
    server.listen(PORT, () => {
      console.log(`✅ Servidor corriendo en ${HOST}:${PORT}/api`);
    });

  } catch (error) {
    console.error("Error en index.js -> setupServer():", error);
  }
}

cron.schedule("* * * * *", async () => {
  // Cron vacío
});


async function setupAPI() {
  try {
    await connectDB();
    await setupServer();
    await createInitialData();
  } catch (error) {
    console.error("Error en index.js -> setupAPI():", error);
  }
}

setupAPI()
  .then(() => console.log("🚀 API Iniciada exitosamente"))
  .catch((error) => console.error("Error al iniciar la API:", error));
