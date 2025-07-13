// src/socket.js
import { Server } from "socket.io";
import { enviarMensaje, editarMensaje, eliminarMensaje } from "./services/chat.service.js";
import { agregarParticipante, eliminarParticipante, obtenerParticipantes } from "./services/chatGrupal.service.js";
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

        // Determinar salas para enviar la actualización
        if (mensajeEditado.receptor) {
          // Chat 1 a 1
          io.to(`usuario_${socket.userId}`).emit("mensaje_editado", mensajeParaEnviar);
          io.to(`usuario_${mensajeEditado.receptor}`).emit("mensaje_editado", mensajeParaEnviar);
          console.log(`📝 Edición enviada a chat 1 a 1: ${socket.userId} ↔ ${mensajeEditado.receptor}`);
        } else if (mensajeEditado.idViajeMongo) {
          // Chat grupal
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

        // Enviar notificación de eliminación a las salas correspondientes
        // Nota: Necesitamos determinar si es chat 1 a 1 o grupal
        // Por ahora enviamos a sala personal del usuario
        io.to(`usuario_${socket.userId}`).emit("mensaje_eliminado", eventoEliminacion);
        console.log(`🗑️ Notificación de eliminación enviada a usuario ${socket.userId}`);

        socket.emit("eliminacion_exitosa", { success: true, idMensaje });

      } catch (error) {
        console.error("❌ Error al eliminar mensaje:", error.message);
        socket.emit("error_eliminacion", { error: error.message });
      }
    });

    socket.on("unirse_viaje", (idViaje) => {
      if (idViaje) {
        socket.join(`viaje_${idViaje}`);
        console.log(`🚗 Usuario ${socket.userId} se unió a sala de viaje: viaje_${idViaje}`);
      }
    });

    socket.on("salir_viaje", (idViaje) => {
      if (idViaje) {
        socket.leave(`viaje_${idViaje}`);
        console.log(`🚗 Usuario ${socket.userId} salió de sala de viaje: viaje_${idViaje}`);
      }
    });

    socket.on("reconectar_usuario", () => {
      socket.join(`usuario_${socket.userId}`);
      console.log(`🔄 Usuario ${socket.userId} reconectado y reregistrado`);
    });

    // ===== EVENTOS ESPECÍFICOS PARA CHAT GRUPAL =====

    // Unirse a chat grupal cuando se confirma como pasajero
    socket.on("unirse_chat_grupal", async (data) => {
      const { idViaje } = data;
      
      if (!idViaje) {
        console.error("❌ ID de viaje es requerido para unirse al chat grupal");
        socket.emit("error_chat_grupal", { error: "ID de viaje es requerido" });
        return;
      }

      try {
        // Unirse a la sala del viaje
        socket.join(`viaje_${idViaje}`);
        console.log(`🚗✅ Usuario ${socket.userId} se unió al chat grupal del viaje ${idViaje}`);
        
        // Obtener participantes actuales del chat
        const participantes = await obtenerParticipantes(idViaje);
        
        // Notificar a todos los participantes que alguien se unió
        socket.to(`viaje_${idViaje}`).emit("participante_unido", {
          idViaje,
          nuevoParticipante: socket.userId,
          participantes
        });

        // Confirmar al usuario que se unió exitosamente
        socket.emit("unido_chat_grupal", {
          success: true,
          idViaje,
          participantes
        });

      } catch (error) {
        console.error("❌ Error al unirse al chat grupal:", error.message);
        socket.emit("error_chat_grupal", { error: error.message });
      }
    });

    // Salir de chat grupal cuando abandona el viaje
    socket.on("salir_chat_grupal", async (data) => {
      const { idViaje } = data;
      
      if (!idViaje) {
        console.error("❌ ID de viaje es requerido para salir del chat grupal");
        socket.emit("error_chat_grupal", { error: "ID de viaje es requerido" });
        return;
      }

      try {
        // Salir de la sala del viaje
        socket.leave(`viaje_${idViaje}`);
        console.log(`🚗❌ Usuario ${socket.userId} salió del chat grupal del viaje ${idViaje}`);
        
        // Obtener participantes restantes del chat
        const participantes = await obtenerParticipantes(idViaje);
        
        // Notificar a todos los participantes restantes
        socket.to(`viaje_${idViaje}`).emit("participante_salio", {
          idViaje,
          participanteSalio: socket.userId,
          participantes
        });

        // Confirmar al usuario que salió exitosamente
        socket.emit("salio_chat_grupal", {
          success: true,
          idViaje
        });

      } catch (error) {
        console.error("❌ Error al salir del chat grupal:", error.message);
        socket.emit("error_chat_grupal", { error: error.message });
      }
    });

    // Obtener estado actual del chat grupal
    socket.on("obtener_estado_chat_grupal", async (data) => {
      const { idViaje } = data;
      
      if (!idViaje) {
        console.error("❌ ID de viaje es requerido para obtener estado del chat");
        socket.emit("error_chat_grupal", { error: "ID de viaje es requerido" });
        return;
      }

      try {
        const participantes = await obtenerParticipantes(idViaje);
        
        socket.emit("estado_chat_grupal", {
          idViaje,
          participantes,
          estaEnChat: participantes.includes(socket.userId)
        });

      } catch (error) {
        console.error("❌ Error al obtener estado del chat grupal:", error.message);
        socket.emit("error_chat_grupal", { error: error.message });
      }
    });

    // Enviar mensaje al chat grupal específico
    socket.on("enviar_mensaje_grupal", async (data) => {
      const { idViaje, contenido } = data;
      
      if (!idViaje) {
        console.error("❌ ID de viaje es requerido para enviar mensaje grupal");
        socket.emit("error_mensaje_grupal", { error: "ID de viaje es requerido" });
        return;
      }

      if (!contenido) {
        console.error("❌ Contenido del mensaje es requerido");
        socket.emit("error_mensaje_grupal", { error: "Contenido del mensaje es requerido" });
        return;
      }

      try {
        // Verificar que el usuario esté en el chat grupal
        const participantes = await obtenerParticipantes(idViaje);
        if (!participantes.includes(socket.userId)) {
          socket.emit("error_mensaje_grupal", { error: "No tienes permisos para enviar mensajes a este chat grupal" });
          return;
        }

        // Enviar mensaje usando el servicio existente
        const mensajeProcesado = await enviarMensaje(
          socket.userId,
          contenido,
          null, // receptor es null para mensajes grupales
          idViaje // idViajeMongo
        );

        console.log(`✅ Mensaje grupal guardado para viaje ${idViaje}`);

        const mensajeParaEnviar = {
          id: mensajeProcesado.id,
          contenido: mensajeProcesado.contenido,
          fecha: mensajeProcesado.fecha,
          emisor: mensajeProcesado.emisor.rut,
          emisorNombre: mensajeProcesado.emisor.nombre,
          idViajeMongo: mensajeProcesado.idViajeMongo,
          editado: false,
          eliminado: false,
          tipo: 'grupal'
        };

        // Enviar a todos los usuarios en el chat grupal
        io.to(`viaje_${idViaje}`).emit("nuevo_mensaje_grupal", mensajeParaEnviar);
        console.log(`📢 Mensaje grupal enviado a chat de viaje ${idViaje}`);

        // Confirmar al emisor
        socket.emit("mensaje_grupal_enviado", {
          success: true,
          idMensaje: mensajeProcesado.id
        });

      } catch (error) {
        console.error("❌ Error al enviar mensaje grupal:", error.message);
        socket.emit("error_mensaje_grupal", { error: error.message });
      }
    });

    // ===== FIN EVENTOS CHAT GRUPAL =====

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

// ===== FUNCIONES ESPECÍFICAS PARA CHAT GRUPAL =====

// Notificar cuando un chat grupal es creado
export function notificarChatGrupalCreado(idViaje, rutConductor) {
  if (io) {
    io.to(`usuario_${rutConductor}`).emit("chat_grupal_creado", {
      idViaje,
      mensaje: "Chat grupal creado para tu viaje"
    });
    console.log(`📢 Notificación enviada: Chat grupal creado para viaje ${idViaje}`);
  }
}

// Notificar cuando un pasajero es agregado al chat grupal
export function notificarParticipanteAgregado(idViaje, rutParticipante, participantes) {
  if (io) {
    // Notificar al participante que fue agregado
    io.to(`usuario_${rutParticipante}`).emit("agregado_chat_grupal", {
      idViaje,
      mensaje: "Has sido agregado al chat grupal del viaje"
    });
    
    // Notificar a todos en el chat grupal
    io.to(`viaje_${idViaje}`).emit("participante_agregado", {
      idViaje,
      nuevoParticipante: rutParticipante,
      participantes
    });
    
    console.log(`📢 Notificación enviada: Participante ${rutParticipante} agregado al viaje ${idViaje}`);
  }
}

// Notificar cuando un pasajero es eliminado del chat grupal
export function notificarParticipanteEliminado(idViaje, rutParticipante, participantes) {
  if (io) {
    // Notificar al participante que fue eliminado
    io.to(`usuario_${rutParticipante}`).emit("eliminado_chat_grupal", {
      idViaje,
      mensaje: "Has sido eliminado del chat grupal del viaje"
    });
    
    // Notificar a todos los participantes restantes
    io.to(`viaje_${idViaje}`).emit("participante_eliminado", {
      idViaje,
      participanteEliminado: rutParticipante,
      participantes
    });
    
    console.log(`📢 Notificación enviada: Participante ${rutParticipante} eliminado del viaje ${idViaje}`);
  }
}

// Notificar cuando un chat grupal es finalizado
export function notificarChatGrupalFinalizado(idViaje, razon = "finalizado") {
  if (io) {
    io.to(`viaje_${idViaje}`).emit("chat_grupal_finalizado", {
      idViaje,
      razon,
      mensaje: `El chat grupal ha sido ${razon}`
    });
    
    console.log(`📢 Notificación enviada: Chat grupal ${razon} para viaje ${idViaje}`);
  }
}

export { io };

