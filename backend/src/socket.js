// src/socket.js
import { Server } from "socket.io";
import { enviarMensaje, editarMensaje, eliminarMensaje, obtenerInfoMensajeParaEliminacion } from "./services/chat.service.js";
import { agregarParticipante, eliminarParticipante, obtenerParticipantes } from "./services/chatGrupal.service.js";
import WebSocketNotificationService from "./services/push_notification.service.js";
import { obtenerUserByRut } from "./services/user.service.js";
import jwt from "jsonwebtoken";
import { ACCESS_TOKEN_SECRET } from "./config/configEnv.js";

let io;

// Función para obtener la instancia de Socket.io
export function getSocketInstance() {
  return io;
}

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
    socket.join(`user_${socket.userId}`); // Para notificaciones de amistad
    console.log(`👤 Usuario ${socket.userId} registrado en salas usuario_${socket.userId} y user_${socket.userId}`);

    // Manejar cuando el usuario se une a una sala específica
    socket.on('joinUserRoom', (userRut) => {
      console.log(`🎯 Solicitud joinUserRoom recibida para: ${userRut}, usuario actual: ${socket.userId}`);
      
      if (userRut === socket.userId) {
        socket.join(`user_${userRut}`);
        console.log(`🔔 Usuario ${userRut} confirmado en sala de notificaciones user_${userRut}`);
        
        // Confirmar que está en las salas
        const rooms = Array.from(socket.rooms);
        console.log(`📍 Usuario ${userRut} está en las salas: ${rooms.join(', ')}`);
        
        // Emitir confirmación de conexión
        socket.emit('notification_connection_confirmed', {
          userRut: userRut,
          timestamp: new Date().toISOString(),
          rooms: rooms
        });
      } else {
        console.warn(`⚠️ Intento de unirse a sala de otro usuario: solicitud=${userRut}, actual=${socket.userId}`);
      }
    });

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
        console.log(`📱 DEVICE DEBUG - Socket enviando mensaje: ${socket.userId} → ${receptorRut || idViajeMongo}`);
        console.log(`📱 DEVICE DEBUG - Contenido: "${contenido}"`);
        console.log(`📱 DEVICE DEBUG - Timestamp: ${new Date().toISOString()}`);
        
        const mensajeProcesado = await enviarMensaje(
          socket.userId,
          contenido,
          receptorRut,
          idViajeMongo
        );

        console.log(`✅ Mensaje guardado y enviando a usuarios...`);
        console.log(`📱 DEVICE DEBUG - Mensaje procesado exitosamente: ID=${mensajeProcesado.id}`);

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

        console.log(`📱 DEVICE DEBUG - Mensaje preparado para envío:`, mensajeParaEnviar);

        if (idViajeMongo) {
          console.log(`📱 DEVICE DEBUG - Enviando a sala de viaje: viaje_${idViajeMongo}`);
          io.to(`viaje_${idViajeMongo}`).emit("nuevo_mensaje", mensajeParaEnviar);
          console.log(`📢 Mensaje enviado a chat de viaje ${idViajeMongo}`);
        } else if (receptorRut) {
          console.log(`📱 DEVICE DEBUG - Enviando a usuarios: ${socket.userId} y ${receptorRut}`);
          io.to(`usuario_${socket.userId}`).emit("nuevo_mensaje", mensajeParaEnviar);
          io.to(`usuario_${receptorRut}`).emit("nuevo_mensaje", mensajeParaEnviar);
          console.log(`💬 Mensaje enviado entre ${socket.userId} y ${receptorRut}`);

          // 🔔 ENVIAR NOTIFICACIÓN PUSH PARA CHAT INDIVIDUAL
          try {
            const [emisorData, errorEmisor] = await obtenerUserByRut(socket.userId);
            if (!errorEmisor && emisorData) {
              console.log(`🔔 Enviando notificación push de chat individual a ${receptorRut}`);
              await WebSocketNotificationService.enviarNotificacionChatIndividual(
                io,
                receptorRut,
                emisorData.nombreCompleto,
                socket.userId,
                contenido
              );
              console.log(`✅ Notificación push enviada exitosamente`);
            } else {
              console.warn(`⚠️ No se pudo obtener datos del emisor ${socket.userId} para notificación`);
            }
          } catch (notifError) {
            console.error(`❌ Error enviando notificación push:`, notifError);
          }
        }

        console.log(`📱 DEVICE DEBUG - Confirmando envío al emisor...`);
        socket.emit("mensaje_enviado", { success: true, mensaje: mensajeParaEnviar });
        console.log(`📱 DEVICE DEBUG - Confirmación enviada al emisor`);

      } catch (error) {
        console.error("❌ Error al procesar mensaje:", error.message);
        console.error(`📱 DEVICE DEBUG - Error en socket enviarMensaje:`, {
          userId: socket.userId,
          receptorRut,
          idViajeMongo,
          contenido,
          error: error.message,
          stack: error.stack
        });
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
        console.log(`📱 DEVICE DEBUG - Socket editando mensaje: ID=${idMensaje}, Editor=${socket.userId}`);
        console.log(`📱 DEVICE DEBUG - Nuevo contenido: "${nuevoContenido}"`);
        
        const mensajeEditado = await editarMensaje(idMensaje, socket.userId, nuevoContenido);

        console.log(`✏️ Mensaje editado por usuario ${socket.userId}: ${idMensaje}`);
        console.log(`✏️ DEBUG: Mensaje editado completo:`, mensajeEditado);
        console.log(`📱 DEVICE DEBUG - Edición exitosa:`, mensajeEditado);

        const mensajeParaEnviar = {
          id: mensajeEditado.id,
          contenido: mensajeEditado.contenido,
          emisor: mensajeEditado.emisor,
          receptor: mensajeEditado.receptor || null,
          idViajeMongo: mensajeEditado.idViajeMongo || null,
          fecha: mensajeEditado.fecha,
          editado: true,
          tipo: mensajeEditado.tipo || (mensajeEditado.receptor ? "personal" : "grupal")
        };

        console.log(`✏️ DEBUG: Mensaje para enviar via socket:`, mensajeParaEnviar);

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
        console.log(`📱 DEVICE DEBUG - Socket eliminando mensaje: ID=${idMensaje}, Usuario=${socket.userId}`);
        
        // Necesitamos obtener la información del mensaje antes de eliminarlo
        const infoMensaje = await obtenerInfoMensajeParaEliminacion(idMensaje, socket.userId);
        
        if (!infoMensaje) {
          console.error(`❌ DEVICE DEBUG - Mensaje no encontrado o sin permisos: ${idMensaje}`);
          throw new Error("Mensaje no encontrado o no tienes permisos para eliminarlo");
        }

        console.log(`📱 DEVICE DEBUG - Info mensaje encontrada:`, infoMensaje);

        // Eliminar el mensaje
        await eliminarMensaje(idMensaje, socket.userId);

        console.log(`🗑️ Mensaje eliminado por usuario ${socket.userId}: ${idMensaje}`);
        console.log(`📱 DEVICE DEBUG - Eliminación exitosa`);

        const eventoEliminacion = {
          idMensaje,
          eliminadoPor: socket.userId,
          fecha: new Date(),
          tipo: infoMensaje.tipo
        };

        console.log(`📱 DEVICE DEBUG - Evento eliminación preparado:`, eventoEliminacion);

        // Enviar notificación de eliminación a las salas correspondientes
        if (infoMensaje.tipo === "personal") {
          // Chat 1 a 1
          console.log(`📱 DEVICE DEBUG - Enviando eliminación a chat personal`);
          io.to(`usuario_${socket.userId}`).emit("mensaje_eliminado", eventoEliminacion);
          io.to(`usuario_${infoMensaje.receptor}`).emit("mensaje_eliminado", eventoEliminacion);
          console.log(`🗑️ Eliminación enviada a chat 1 a 1: ${socket.userId} ↔ ${infoMensaje.receptor}`);
        } else if (infoMensaje.tipo === "grupal") {
          // Chat grupal
          io.to(`viaje_${infoMensaje.idViajeMongo}`).emit("mensaje_eliminado", eventoEliminacion);
          console.log(`🗑️ Eliminación enviada a chat de viaje: ${infoMensaje.idViajeMongo}`);
        }

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

        // 🔔 ENVIAR NOTIFICACIONES PUSH PARA CHAT GRUPAL
        try {
          const [emisorData, errorEmisor] = await obtenerUserByRut(socket.userId);
          if (!errorEmisor && emisorData) {
            console.log(`🔔 Enviando notificaciones push de chat grupal a participantes del viaje ${idViaje}`);
            
            // Obtener participantes del chat grupal (excluyendo al emisor)
            const participantesViaje = await obtenerParticipantes(idViaje);
            const nombreGrupo = `Viaje Chat`; // Por ahora un nombre genérico
            
            // Enviar notificación a cada participante (excepto el emisor)
            for (const rutParticipante of participantesViaje) {
              if (rutParticipante !== socket.userId) {
                try {
                  await WebSocketNotificationService.enviarNotificacionChatGrupal(
                    io,
                    rutParticipante,
                    emisorData.nombreCompleto,
                    socket.userId,
                    contenido,
                    idViaje,
                    nombreGrupo
                  );
                  console.log(`✅ Notificación grupal enviada a ${rutParticipante}`);
                } catch (notifParticipanteError) {
                  console.error(`❌ Error enviando notificación a ${rutParticipante}:`, notifParticipanteError);
                }
              }
            }
          } else {
            console.warn(`⚠️ No se pudo obtener datos del emisor ${socket.userId} para notificación grupal`);
          }
        } catch (notifGrupalError) {
          console.error(`❌ Error enviando notificaciones push grupales:`, notifGrupalError);
        }

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

    // Editar mensaje en chat grupal
    socket.on("editar_mensaje_grupal", async (data) => {
      const { idMensaje, nuevoContenido, idViaje } = data;
      
      if (!idMensaje || !nuevoContenido || !idViaje) {
        console.error("❌ ID del mensaje, nuevo contenido e ID de viaje son requeridos");
        socket.emit("error_edicion_grupal", { error: "ID del mensaje, nuevo contenido e ID de viaje son requeridos" });
        return;
      }

      try {
        // Verificar que el usuario esté en el chat grupal
        const participantes = await obtenerParticipantes(idViaje);
        if (!participantes.includes(socket.userId)) {
          socket.emit("error_edicion_grupal", { error: "No tienes permisos para editar mensajes en este chat grupal" });
          return;
        }

        const mensajeEditado = await editarMensaje(idMensaje, socket.userId, nuevoContenido);

        console.log(`✏️ Mensaje grupal editado por usuario ${socket.userId}: ${idMensaje}`);

        const mensajeParaEnviar = {
          id: mensajeEditado.id,
          contenido: mensajeEditado.contenido,
          emisor: mensajeEditado.emisor,
          idViajeMongo: idViaje,
          fecha: mensajeEditado.fecha,
          editado: true,
          tipo: "grupal"
        };

        // Enviar a todos los usuarios en el chat grupal
        io.to(`viaje_${idViaje}`).emit("mensaje_editado", mensajeParaEnviar);
        console.log(`📝 Edición grupal enviada a chat de viaje: ${idViaje}`);

        socket.emit("edicion_grupal_exitosa", { success: true, mensaje: mensajeParaEnviar });

      } catch (error) {
        console.error("❌ Error al editar mensaje grupal:", error.message);
        socket.emit("error_edicion_grupal", { error: error.message });
      }
    });

    // Eliminar mensaje en chat grupal
    socket.on("eliminar_mensaje_grupal", async (data) => {
      const { idMensaje, idViaje } = data;
      
      if (!idMensaje || !idViaje) {
        console.error("❌ ID del mensaje e ID de viaje son requeridos");
        socket.emit("error_eliminacion_grupal", { error: "ID del mensaje e ID de viaje son requeridos" });
        return;
      }

      try {
        // Verificar que el usuario esté en el chat grupal
        const participantes = await obtenerParticipantes(idViaje);
        if (!participantes.includes(socket.userId)) {
          socket.emit("error_eliminacion_grupal", { error: "No tienes permisos para eliminar mensajes en este chat grupal" });
          return;
        }

        // Obtener info del mensaje antes de eliminarlo
        const infoMensaje = await obtenerInfoMensajeParaEliminacion(idMensaje, socket.userId);
        
        if (!infoMensaje || infoMensaje.tipo !== "grupal") {
          throw new Error("Mensaje no encontrado o no es de tipo grupal");
        }

        // Eliminar el mensaje
        await eliminarMensaje(idMensaje, socket.userId);

        console.log(`🗑️ Mensaje grupal eliminado por usuario ${socket.userId}: ${idMensaje}`);

        const eventoEliminacion = {
          idMensaje,
          eliminadoPor: socket.userId,
          fecha: new Date(),
          tipo: "grupal"
        };

        // Enviar a todos los usuarios en el chat grupal
        io.to(`viaje_${idViaje}`).emit("mensaje_eliminado", eventoEliminacion);
        console.log(`🗑️ Eliminación grupal enviada a chat de viaje: ${idViaje}`);

        socket.emit("eliminacion_grupal_exitosa", { success: true, idMensaje });

      } catch (error) {
        console.error("❌ Error al eliminar mensaje grupal:", error.message);
        socket.emit("error_eliminacion_grupal", { error: error.message });
      }
    });

    // ===== FIN EVENTOS CHAT GRUPAL =====

    // ===== EVENTOS DE PROCESAMIENTO AUTOMÁTICO =====
    
    // Procesar estados automáticos de viajes (solo para admins o sistema automatizado)
    socket.on("procesar_estados_automaticos", async () => {
      try {
        console.log(`🔄 Procesamiento automático solicitado por usuario: ${socket.userId}`);
        
        // Importar la función de procesamiento
        const { procesarCambiosEstadoAutomaticos } = await import('./services/viaje.validation.service.js');
        
        const resultado = await procesarCambiosEstadoAutomaticos();
        
        if (resultado.exito) {
          // Emitir resultado al usuario que solicitó
          socket.emit("estados_automaticos_procesados", {
            exito: true,
            procesados: resultado.procesados,
            cancelados: resultado.cancelados,
            iniciados: resultado.iniciados,
            timestamp: new Date().toISOString()
          });
          
          // Emitir a todos los usuarios sobre cambios de estado si hubo procesos
          if (resultado.procesados > 0) {
            io.emit("viajes_estado_actualizado", {
              procesados: resultado.procesados,
              cancelados: resultado.cancelados,
              iniciados: resultado.iniciados
            });
          }
          
          console.log(`✅ Procesamiento automático completado: ${resultado.procesados} viajes procesados`);
        } else {
          socket.emit("estados_automaticos_error", { 
            error: resultado.mensaje || "Error en procesamiento automático" 
          });
        }
        
      } catch (error) {
        console.error("❌ Error en procesamiento automático via socket:", error.message);
        socket.emit("estados_automaticos_error", { error: error.message });
      }
    });

    // ===== FIN EVENTOS PROCESAMIENTO AUTOMÁTICO =====

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

