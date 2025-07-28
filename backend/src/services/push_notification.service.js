"use strict";

/**
 * Servicio de notificaciones WebSocket
 * Reemplaza Firebase con sistema basado en WebSocket para notificaciones en tiempo real
 */
class WebSocketNotificationService {
  
  /**
   * Enviar notificación WebSocket a un usuario específico
   */
    /**
   * Enviar notificación cuando un pasajero abandona el viaje
   */
  static async enviarPasajeroAbandono(io, rutConductor, nombrePasajero, rutPasajero, datosViaje) {
    return await this.enviarNotificacionAUsuario(
      io,
      rutConductor,
      '👋 Pasajero abandonó el viaje',
      `${nombrePasajero} ha abandonado tu viaje de ${datosViaje.origen} a ${datosViaje.destino}`,
      {
        tipo: 'pasajero_abandono',
        rutEmisor: rutPasajero,
        nombreEmisor: nombrePasajero,
        viajeId: datosViaje.viajeId,
        origen: datosViaje.origen,
        destino: datosViaje.destino,
        fechaViaje: datosViaje.fechaViaje,
        horaViaje: datosViaje.horaViaje,
        plazasLiberadas: datosViaje.plazasLiberadas,
        nuevasPlazasDisponibles: datosViaje.nuevasPlazasDisponibles,
        accion: 'actualizar_viaje'
      }
    );
  }

  /**
   * Enviar notificación cuando un conductor elimina a un pasajero del viaje
   */
  static async enviarPasajeroEliminado(io, rutPasajero, nombreConductor, rutConductor, datosViaje, reembolsoProcesado, mensajeDevolucion) {
    const mensajeCompleto = reembolsoProcesado 
      ? `${nombreConductor} te ha eliminado del viaje. ${mensajeDevolucion}`
      : `${nombreConductor} te ha eliminado del viaje.`;

    return await this.enviarNotificacionAUsuario(
      io,
      rutPasajero,
      '🚫 Eliminado de viaje',
      mensajeCompleto,
      {
        tipo: 'pasajero_eliminado',
        rutEmisor: rutConductor,
        nombreEmisor: nombreConductor,
        viajeId: datosViaje.viajeId,
        origen: datosViaje.origen,
        destino: datosViaje.destino,
        fechaViaje: datosViaje.fechaViaje,
        horaViaje: datosViaje.horaViaje,
        reembolsoProcesado: reembolsoProcesado,
        mensajeDevolucion: mensajeDevolucion,
        accion: 'eliminar_viaje'
      }
    );
  }

  /**
   * Verificar si un usuario está conectado via WebSocket
   */
  static verificarUsuarioConectado(io, rutUsuario) {
    if (!io) return false;
    
    const sockets = io.sockets.sockets;
    for (const [socketId, socket] of sockets) {
      if (socket.data?.rutUsuario === rutUsuario) {
        return true;
      }
    }
    return false;
  }

  /**
   * Enviar notificación a un usuario específico
   */
  static async enviarNotificacionAUsuario(io, rutUsuario, titulo, mensaje, datos = {}) {
    try {
      if (!io) {
        console.warn('⚠️ Socket.io no está disponible');
        return { success: false, error: 'Socket.io no disponible' };
      }

      if (!io.to || typeof io.to !== 'function') {
        console.error('⚠️ Socket.io instance no válida - io.to no es una función');
        console.error('⚠️ Tipo de io:', typeof io);
        console.error('⚠️ io.to:', io.to);
        return { success: false, error: 'Socket.io instance inválida' };
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

      // Para eventos específicos de amistad, enviar SOLO el evento específico para evitar duplicados
      const eventosEspecificos = ['solicitud_amistad', 'amistad_aceptada', 'amistad_rechazada'];
      const esEventoAmistad = datos.tipo && eventosEspecificos.includes(datos.tipo);

      if (esEventoAmistad) {
        // Para eventos de amistad: SOLO enviar evento específico
        console.log(`📤 Enviando SOLO evento específico '${datos.tipo}' a user_${rutUsuario}:`, baseData);
        io.to(`user_${rutUsuario}`).emit(datos.tipo, baseData);
        io.to(`usuario_${rutUsuario}`).emit(datos.tipo, baseData);
      } else {
        // Para otros eventos: enviar evento genérico
        io.to(`user_${rutUsuario}`).emit('nueva_notificacion', baseData);
        io.to(`usuario_${rutUsuario}`).emit('nueva_notificacion', baseData);

        // También emitir evento específico si existe
        if (datos.tipo) {
          console.log(`📤 Enviando evento específico '${datos.tipo}' a user_${rutUsuario}:`, baseData);
          io.to(`user_${rutUsuario}`).emit(datos.tipo, baseData);
          io.to(`usuario_${rutUsuario}`).emit(datos.tipo, baseData);
        }
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
   * Enviar notificación de solicitud de viaje aceptada
   */
  static async enviarViajeAceptado(io, rutPasajero, nombreConductor, rutConductor, datosViaje) {
    return await this.enviarNotificacionAUsuario(
      io,
      rutPasajero,
      '🎉 ¡Viaje aceptado!',
      `${nombreConductor} aceptó tu solicitud para el viaje de ${datosViaje.origen} a ${datosViaje.destino}`,
      {
        tipo: 'ride_accepted',
        rutEmisor: rutConductor,
        nombreEmisor: nombreConductor,
        viajeId: datosViaje.viajeId,
        origen: datosViaje.origen,
        destino: datosViaje.destino,
        fechaViaje: datosViaje.fechaViaje,
        horaViaje: datosViaje.horaViaje,
        mostrarAnimacion: true,
        accion: 'abrir_viaje'
      }
    );
  }

  /**
   * Enviar notificación de solicitud de viaje rechazada
   */
  static async enviarViajeRechazado(io, rutPasajero, nombreConductor, rutConductor, datosViaje) {
    return await this.enviarNotificacionAUsuario(
      io,
      rutPasajero,
      '😔 Solicitud rechazada',
      `${nombreConductor} rechazó tu solicitud para el viaje de ${datosViaje.origen} a ${datosViaje.destino}`,
      {
        tipo: 'ride_rejected',
        rutEmisor: rutConductor,
        nombreEmisor: nombreConductor,
        viajeId: datosViaje.viajeId,
        origen: datosViaje.origen,
        destino: datosViaje.destino,
        accion: 'buscar_viajes'
      }
    );
  }

  /**
   * Enviar notificación de solicitud de viaje
   */
  static async enviarSolicitudViaje(io, rutConductor, nombrePasajero, rutPasajero, datosViaje) {
    return await this.enviarNotificacionAUsuario(
      io,
      rutConductor,
      '🚗 Nueva solicitud de viaje',
      `${nombrePasajero} quiere unirse a tu viaje de ${datosViaje.origen} a ${datosViaje.destino}`,
      {
        tipo: 'solicitud_viaje',
        rutEmisor: rutPasajero,
        nombreEmisor: nombrePasajero,
        viajeId: datosViaje.viajeId,
        origen: datosViaje.origen,
        destino: datosViaje.destino,
        precio: datosViaje.precio,
        fechaViaje: datosViaje.fechaViaje,
        horaViaje: datosViaje.horaViaje,
        pago: datosViaje.pago || null,
        accion: 'abrir_solicitudes_pasajeros'
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
   * Enviar notificación de mensaje de chat individual
   */
  static async enviarNotificacionChatIndividual(io, rutReceptor, nombreEmisor, rutEmisor, mensaje) {
    const mensajeCorto = mensaje.length > 50 ? mensaje.substring(0, 50) + '...' : mensaje;
    
    return await this.enviarNotificacionAUsuario(
      io,
      rutReceptor,
      `💬 ${nombreEmisor}`,
      mensajeCorto,
      {
        tipo: 'chat_individual',
        rutEmisor: rutEmisor,
        nombreEmisor: nombreEmisor,
        mensaje: mensaje,
        chatId: `${rutEmisor}_${rutReceptor}`,
        accion: 'abrir_chat_individual'
      }
    );
  }

  /**
   * Enviar notificación de mensaje de chat grupal
   */
  static async enviarNotificacionChatGrupal(io, rutReceptor, nombreEmisor, rutEmisor, mensaje, grupoId, nombreGrupo) {
    const mensajeCorto = mensaje.length > 50 ? mensaje.substring(0, 50) + '...' : mensaje;
    
    return await this.enviarNotificacionAUsuario(
      io,
      rutReceptor,
      `👥 ${nombreGrupo}`,
      `${nombreEmisor}: ${mensajeCorto}`,
      {
        tipo: 'chat_grupal',
        rutEmisor: rutEmisor,
        nombreEmisor: nombreEmisor,
        mensaje: mensaje,
        grupoId: grupoId,
        nombreGrupo: nombreGrupo,
        accion: 'abrir_chat_grupal'
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
   * Enviar notificación de nueva solicitud de soporte a administradores
   */
  static async enviarNotificacionSoporteAAdministradores(io, rutesAdministradores, nombreUsuario, rutUsuario, datosPeticion) {
    return await this.enviarNotificacionMasiva(
      io,
      rutesAdministradores,
      '🆘 Nueva solicitud de soporte',
      `${nombreUsuario} necesita soporte`,
      {
        tipo: 'nueva_peticion_soporte',
        rutEmisor: rutUsuario,
        nombreEmisor: nombreUsuario,
        peticionId: datosPeticion.peticionId,
        motivo: datosPeticion.motivo,
        prioridad: datosPeticion.prioridad,
        mensaje: datosPeticion.mensaje,
        fechaCreacion: datosPeticion.fechaCreacion,
        accion: 'abrir_panel_admin'
      }
    );
  }

  /**
   * Enviar notificación cuando un pasajero abandona el viaje
   */
  static async enviarPasajeroAbandono(io, rutConductor, nombrePasajero, rutPasajero, datosViaje) {
    return await this.enviarNotificacionAUsuario(
      io,
      rutConductor,
      '👋 Pasajero abandonó el viaje',
      `${nombrePasajero} ha abandonado tu viaje de ${datosViaje.origen} a ${datosViaje.destino}`,
      {
        tipo: 'pasajero_abandono',
        rutEmisor: rutPasajero,
        nombreEmisor: nombrePasajero,
        viajeId: datosViaje.viajeId,
        origen: datosViaje.origen,
        destino: datosViaje.destino,
        fechaViaje: datosViaje.fechaViaje,
        horaViaje: datosViaje.horaViaje,
        plazasLiberadas: datosViaje.plazasLiberadas,
        nuevasPlazasDisponibles: datosViaje.nuevasPlazasDisponibles,
        accion: 'actualizar_viaje'
      }
    );
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

// Exportaciones específicas para compatibilidad
export const enviarPasajeroAbandono = WebSocketNotificationService.enviarPasajeroAbandono;
export const enviarPasajeroEliminado = WebSocketNotificationService.enviarPasajeroEliminado;
export const enviarNotificacionAUsuario = WebSocketNotificationService.enviarNotificacionAUsuario;
export const verificarUsuarioConectado = WebSocketNotificationService.verificarUsuarioConectado;
