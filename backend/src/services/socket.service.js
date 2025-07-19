import { Server } from "socket.io";
import { enviarMensaje, editarMensaje, eliminarMensaje } from "./chat.service.js";
import jwt from "jsonwebtoken";
import { ACCESS_TOKEN_SECRET } from "../config/configEnv.js";

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

function initializeSocket(server) {
  io = new Server(server, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
    }
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
        const mensajeProcesado = await enviarMensaje(
          socket.userId,
          contenido,
          receptorRut,
          idViajeMongo
        );

        console.log(`✅ Mensaje guardado y enviando a usuarios...`);

        const mensajeParaEnviar = {
          id: mensajeProcesado.id,
          contenido: mensajeProcesado.contenido,
          fecha: mensajeProcesado.fecha,
          emisor: mensajeProcesado.emisor.rut,
          receptor: mensajeProcesado.receptor?.rut || null,
          idViajeMongo: mensajeProcesado.idViajeMongo,
          editado: false,
          eliminado: false
        };

        if (idViajeMongo) {
          io.to(`viaje_${idViajeMongo}`).emit("nuevo_mensaje", mensajeParaEnviar);
          console.log(`📢 Mensaje enviado a chat de viaje ${idViajeMongo}`);
        } else if (receptorRut) {
          io.to(`usuario_${socket.userId}`).emit("nuevo_mensaje", mensajeParaEnviar);
          io.to(`usuario_${receptorRut}`).emit("nuevo_mensaje", mensajeParaEnviar);
          console.log(`💬 Mensaje enviado entre ${socket.userId} y ${receptorRut}`);
        }

        socket.emit("mensaje_enviado", { success: true, mensaje: mensajeParaEnviar });

      } catch (error) {
        console.error("❌ Error al procesar mensaje:", error.message);
        socket.emit("error_mensaje", { error: error.message });
      }
    });

    // Manejar edición de mensajes
    socket.on("editar_mensaje", async (data) => {
      const { idMensaje, nuevoContenido } = data;
      
      if (!idMensaje || !nuevoContenido) {
        console.error("❌ ID del mensaje y nuevo contenido son requeridos");
        socket.emit("error_edicion", { error: "ID del mensaje y nuevo contenido son requeridos" });
        return;
      }

      try {
        const mensajeEditado = await editarMensaje(idMensaje, socket.userId, nuevoContenido);

        console.log(`✏️ Mensaje editado por usuario ${socket.userId}: ${idMensaje}`);

        const mensajeParaEnviar = {
          id: mensajeEditado.id,
          contenido: mensajeEditado.contenido,
          emisor: mensajeEditado.emisor,
          fecha: mensajeEditado.fecha,
          editado: true
        };

        if (mensajeEditado.receptor) {
          io.to(`usuario_${socket.userId}`).emit("mensaje_editado", mensajeParaEnviar);
          io.to(`usuario_${mensajeEditado.receptor}`).emit("mensaje_editado", mensajeParaEnviar);
          console.log(`📝 Edición enviada a chat 1 a 1: ${socket.userId} ↔ ${mensajeEditado.receptor}`);
        } else if (mensajeEditado.idViajeMongo) {
          io.to(`viaje_${mensajeEditado.idViajeMongo}`).emit("mensaje_editado", mensajeParaEnviar);
          console.log(`📝 Edición enviada a chat de viaje: ${mensajeEditado.idViajeMongo}`);
        }

        socket.emit("edicion_exitosa", { success: true, mensaje: mensajeParaEnviar });

      } catch (error) {
        console.error("❌ Error al editar mensaje:", error.message);
        socket.emit("error_edicion", { error: error.message });
      }
    });

    // Manejar eliminación de mensajes
    socket.on("eliminar_mensaje", async (data) => {
      const { idMensaje } = data;
      
      if (!idMensaje) {
        console.error("❌ ID del mensaje es requerido para eliminación");
        socket.emit("error_eliminacion", { error: "ID del mensaje es requerido" });
        return;
      }

      try {
        await eliminarMensaje(idMensaje, socket.userId);

        console.log(`🗑️ Mensaje eliminado por usuario ${socket.userId}: ${idMensaje}`);

        const eventoEliminacion = {
          idMensaje,
          eliminadoPor: socket.userId,
          fecha: new Date()
        };

        io.to(`usuario_${socket.userId}`).emit("mensaje_eliminado", eventoEliminacion);
        console.log(`🗑️ Notificación de eliminación enviada a usuario ${socket.userId}`);

        socket.emit("eliminacion_exitosa", { success: true, idMensaje });

      } catch (error) {
        console.error("❌ Error al eliminar mensaje:", error.message);
        socket.emit("error_eliminacion", { error: error.message });
      }
    });

    // Unirse a sala de viaje
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

// Función para obtener la instancia de 'io'
function getIO() {
  if (!io) {
    throw new Error("Socket.io no ha sido inicializado.");
  }
  return io;
}

// Función para enviar mensajes desde otros servicios
export function emitToUser(rutUsuario, event, data) {
  if (io) {
    io.to(`usuario_${rutUsuario}`).emit(event, data);
    console.log(`📤 Evento enviado a usuario ${rutUsuario}: ${event}`);
  }
}

export function emitToViaje(idViaje, event, data) {
  if (io) {
    io.to(`viaje_${idViaje}`).emit(event, data);
    console.log(`📤 Evento enviado a viaje ${idViaje}: ${event}`);
  }
}

export {
  initializeSocket,
  getIO,
};
