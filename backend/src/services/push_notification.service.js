"use strict";

/**
 * Servicio de notificaciones WebSocket
 * Reemplaza Firebase con sistema basado en WebSocket para notificaciones en tiempo real
 */
class WebSocketNotificationService {
  
  /**
   * Enviar notificación WebSocket a un usuario específico
   */
  static async enviarNotificacionAUsuario(io, rutUsuario, titulo, mensaje, datos = {}) {
    try {
      if (!io) {
        console.warn('⚠️ Socket.io no está disponible');
        return { success: false, error: 'Socket.io no disponible' };
      }

      if (!rutUsuario) {
        console.warn('⚠️ No se proporcionó RUT de usuario');
        return { success: false, error: 'RUT de usuario no disponible' };
      }

      const baseData = {
        titulo: titulo,
        mensaje: mensaje,
        timestamp: new Date().toISOString(),
        ...datos
      };

      console.log(`📤 Enviando notificación a user_${rutUsuario}:`, baseData);

      // Enviar evento genérico nueva_notificacion
      io.to(`user_${rutUsuario}`).emit('nueva_notificacion', baseData);
      io.to(`usuario_${rutUsuario}`).emit('nueva_notificacion', baseData);

      // También emitir evento específico según el tipo
      if (datos.tipo) {
        console.log(`📤 Enviando evento específico '${datos.tipo}' a user_${rutUsuario}:`, baseData);
        io.to(`user_${rutUsuario}`).emit(datos.tipo, baseData);
        io.to(`usuario_${rutUsuario}`).emit(datos.tipo, baseData);
      }

      // Verificar cuántos clientes están conectados
      const roomSize = io.sockets.adapter.rooms.get(`user_${rutUsuario}`)?.size || 0;
      console.log(`✅ Notificación WebSocket enviada a ${rutUsuario} (${roomSize} clientes conectados)`);
      
      return { success: true, clientsReached: roomSize };
      
    } catch (error) {
      console.error('❌ Error enviando notificación WebSocket:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Enviar notificación de solicitud de amistad
   */
  static async enviarSolicitudAmistad(io, rutReceptor, nombreEmisor, rutEmisor) {
    return await this.enviarNotificacionAUsuario(
      io,
      rutReceptor,
      '👋 Nueva solicitud de amistad',
      `${nombreEmisor} te ha enviado una solicitud de amistad`,
      {
        tipo: 'solicitud_amistad',
        rutEmisor: rutEmisor,
        nombreEmisor: nombreEmisor,
        accion: 'abrir_solicitudes'
      }
    );
  }

  /**
   * Enviar notificación de amistad aceptada
   */
  static async enviarAmistadAceptada(io, rutEmisor, nombreReceptor, rutReceptor) {
    return await this.enviarNotificacionAUsuario(
      io,
      rutEmisor,
      '🎉 ¡Nueva amistad!',
      `Ahora eres amigo de ${nombreReceptor}`,
      {
        tipo: 'amistad_aceptada',
        rutReceptor: rutReceptor,
        nombreReceptor: nombreReceptor,
        accion: 'abrir_amigos'
      }
    );
  }

  /**
   * Enviar notificación de amistad rechazada
   */
  static async enviarAmistadRechazada(io, rutEmisor, nombreReceptor, rutReceptor) {
    return await this.enviarNotificacionAUsuario(
      io,
      rutEmisor,
      '😔 Solicitud rechazada',
      `${nombreReceptor} ha rechazado tu solicitud de amistad`,
      {
        tipo: 'amistad_rechazada',
        rutReceptor: rutReceptor,
        nombreReceptor: nombreReceptor,
        accion: 'ninguna'
      }
    );
  }

  /**
   * Enviar notificación de nuevo viaje
   */
  static async enviarNuevoViaje(io, rutUsuario, nombreConductor, origen, destino, viajeId) {
    return await this.enviarNotificacionAUsuario(
      io,
      rutUsuario,
      '🚗 Nuevo viaje disponible',
      `${nombreConductor} publicó un viaje de ${origen} a ${destino}`,
      {
        tipo: 'viaje_nuevo',
        viajeId: viajeId,
        origen: origen,
        destino: destino,
        nombreConductor: nombreConductor,
        accion: 'abrir_viaje'
      }
    );
  }

  /**
   * Enviar notificación a múltiples usuarios por WebSocket
   */
  static async enviarNotificacionMasiva(io, rutUsuarios, titulo, mensaje, datos = {}) {
    try {
      const validRuts = rutUsuarios.filter(rut => rut && rut.trim() !== '');
      
      if (validRuts.length === 0) {
        console.warn('⚠️ No hay RUTs válidos para envío masivo');
        return { success: false, error: 'No hay RUTs válidos' };
      }

      let successCount = 0;
      const resultados = [];

      for (const rut of validRuts) {
        try {
          const resultado = await this.enviarNotificacionAUsuario(io, rut, titulo, mensaje, datos);
          if (resultado.success) {
            successCount++;
          }
          resultados.push({ rut, success: resultado.success });
        } catch (error) {
          console.error(`Error enviando a ${rut}:`, error);
          resultados.push({ rut, success: false, error: error.message });
        }
      }

      console.log(`✅ Notificaciones masivas enviadas: ${successCount}/${validRuts.length}`);
      
      return { 
        success: true, 
        successCount: successCount,
        failureCount: validRuts.length - successCount,
        resultados: resultados
      };
      
    } catch (error) {
      console.error('❌ Error enviando notificaciones masivas:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Verificar si un usuario está conectado por WebSocket
   */
  static verificarUsuarioConectado(io, rutUsuario) {
    try {
      const roomSize = io.sockets.adapter.rooms.get(`user_${rutUsuario}`)?.size || 0;
      return { 
        conectado: roomSize > 0, 
        clientesConectados: roomSize 
      };
    } catch (error) {
      console.error(`Error verificando conexión de ${rutUsuario}:`, error);
      return { conectado: false, clientesConectados: 0 };
    }
  }
}

export default WebSocketNotificationService;
