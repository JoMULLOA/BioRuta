// src/socket.js
import { Server } from "socket.io";
import { enviarMensaje } from "./services/chat.service.js";
import jwt from "jsonwebtoken";
import { ACCESS_TOKEN_SECRET } from "./config/configEnv.js";

let io;

// Middleware de autenticación para sockets
const authenticateSocket = (socket, next) => {
  try {
    const token = socket.handshake.auth.token;
    if (!token) {
      return next(new Error("No token provided"));
    }

    const decoded = jwt.verify(token, ACCESS_TOKEN_SECRET);
    socket.userId = decoded.rut;
    socket.userEmail = decoded.email;
    console.log(`🔐 Socket autenticado para usuario: ${decoded.rut}`);
    next();
  } catch (error) {
    console.error("❌ Error de autenticación de socket:", error.message);
    next(new Error("Authentication error"));
  }
};

export function initSocket(server) {
  io = new Server(server, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
    },
  });

  // Aplicar middleware de autenticación
  io.use(authenticateSocket);

  io.on("connection", (socket) => {
    console.log(`🔌 Usuario conectado: ${socket.id} (RUT: ${socket.userId})`);

    // Registrar usuario en su sala personal automáticamente
    socket.join(`usuario_${socket.userId}`);
    console.log(`👤 Usuario ${socket.userId} registrado en sala usuario_${socket.userId}`);

    // Manejar envío de mensajes
    socket.on("enviar_mensaje", async (data) => {
      const { contenido, receptorRut, idViajeMongo } = data;
      
      if (!contenido) {
        console.error("❌ Contenido del mensaje es requerido");
        socket.emit("error_mensaje", { error: "Contenido del mensaje es requerido" });
        return;
      }

      if (!receptorRut && !idViajeMongo) {
        console.error("❌ Se debe especificar receptorRut o idViajeMongo");
        socket.emit("error_mensaje", { error: "Se debe especificar receptorRut o idViajeMongo" });
        return;
      }

      try {
        // Usar el servicio existente para guardar el mensaje
        const mensajeGuardado = await enviarMensaje(
          socket.userId,
          contenido,
          receptorRut,
          idViajeMongo
        );

        console.log(`✅ Mensaje guardado y enviando a usuarios...`);

        // Preparar datos del mensaje para enviar
        const mensajeParaEnviar = {
          id: mensajeGuardado.id,
          contenido: mensajeGuardado.contenido,
          fecha: mensajeGuardado.fecha,
          emisor: {
            rut: mensajeGuardado.emisor.rut,
            nombreCompleto: mensajeGuardado.emisor.nombreCompleto,
          },
          receptor: mensajeGuardado.receptor ? {
            rut: mensajeGuardado.receptor.rut,
            nombreCompleto: mensajeGuardado.receptor.nombreCompleto,
          } : null,
          idViajeMongo: mensajeGuardado.idViajeMongo,
        };

        if (idViajeMongo) {
          // Para chat de viaje, enviar a la sala del viaje
          io.to(`viaje_${idViajeMongo}`).emit("nuevo_mensaje", mensajeParaEnviar);
          console.log(`📢 Mensaje enviado a chat de viaje ${idViajeMongo}`);
        } else if (receptorRut) {
          // Para chat 1 a 1, enviar al emisor y receptor
          io.to(`usuario_${socket.userId}`).emit("nuevo_mensaje", mensajeParaEnviar);
          io.to(`usuario_${receptorRut}`).emit("nuevo_mensaje", mensajeParaEnviar);
          
          console.log(`💬 Mensaje enviado entre ${socket.userId} y ${receptorRut}`);
        }

        // Confirmar al emisor que el mensaje se envió
        socket.emit("mensaje_enviado", { success: true, mensaje: mensajeParaEnviar });

      } catch (error) {
        console.error("❌ Error al procesar mensaje:", error.message);
        socket.emit("error_mensaje", { error: error.message });
      }
    });

    // Unirse a sala de viaje (para chats grupales)
    socket.on("unirse_viaje", (idViaje) => {
      if (idViaje) {
        socket.join(`viaje_${idViaje}`);
        console.log(`🚗 Usuario ${socket.userId} se unió a sala de viaje: viaje_${idViaje}`);
      }
    });

    // Salir de sala de viaje
    socket.on("salir_viaje", (idViaje) => {
      if (idViaje) {
        socket.leave(`viaje_${idViaje}`);
        console.log(`🚗 Usuario ${socket.userId} salió de sala de viaje: viaje_${idViaje}`);
      }
    });

    // Manejar reconexión
    socket.on("reconectar_usuario", () => {
      socket.join(`usuario_${socket.userId}`);
      console.log(`🔄 Usuario ${socket.userId} reconectado y reregistrado`);
    });

    socket.on("disconnect", () => {
      console.log(`🔌 Usuario desconectado: ${socket.id} (RUT: ${socket.userId})`);
    });
  });

  return io;
}

// Función para enviar mensajes desde otros servicios
export function emitToUser(rutUsuario, event, data) {
  if (io) {
    io.to(`usuario_${rutUsuario}`).emit(event, data);
  }
}

export function emitToViaje(idViaje, event, data) {
  if (io) {
    io.to(`viaje_${idViaje}`).emit(event, data);
  }
}

export { io };

