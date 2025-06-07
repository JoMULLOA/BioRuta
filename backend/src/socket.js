// src/socket.js
import { Server } from "socket.io";
import { enviarMensaje } from "./services/chat.service.js"; // 👈 reutilizamos el servicio

let io;

export function initSocket(server) {
  io = new Server(server, {
    cors: {
      origin: "*",
    },
  });

  io.on("connection", (socket) => {
    console.log(`🔌 Usuario conectado: ${socket.id}`);

    socket.on("registrar_usuario", (rutUsuario) => {
      socket.join(`usuario_${rutUsuario}`);
    });

    socket.on("enviar_mensaje", async ({ emisorRut, receptorRut, contenido }) => {
      if (!contenido || !emisorRut || !receptorRut) return;

      try {
        const mensajeGuardado = await enviarMensaje(emisorRut, receptorRut, contenido);

        // Emitir el mensaje al emisor y receptor
        io.to(`usuario_${emisorRut}`).emit("nuevo_mensaje", mensajeGuardado);
        io.to(`usuario_${receptorRut}`).emit("nuevo_mensaje", mensajeGuardado);
      } catch (error) {
        console.error("Error al guardar o emitir mensaje:", error);
      }
    });

    socket.on("disconnect", () => {
      console.log(`🔌 Usuario desconectado: ${socket.id}`);
    });
  });
}

export { io };

