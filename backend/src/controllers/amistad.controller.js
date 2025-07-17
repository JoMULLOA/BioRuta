"use strict";
import {
  enviarSolicitudAmistadService,
  responderSolicitudAmistadService,
  obtenerSolicitudesPendientesService,
  obtenerAmigosService,
  eliminarAmistadService
} from "../services/amistad.service.js";
import {
  crearNotificacionService
} from "../services/notificacion.service.js";
import WebSocketNotificationService from "../services/push_notification.service.js";
import {
  solicitudAmistadBodyValidation,
  respuestaSolicitudValidation,
  rutValidation
} from "../validations/amistad.validation.js";
import {
  handleErrorClient,
  handleErrorServer,
  handleSuccess,
} from "../handlers/responseHandlers.js";

export async function enviarSolicitudAmistad(req, res) {
  try {
    const { error } = solicitudAmistadBodyValidation.validate(req.body);
    
    if (error) {
      return handleErrorClient(res, 400, error.details[0].message);
    }

    const { rutReceptor, mensaje } = req.body;
    const rutEmisor = req.user.rut;

    const [solicitud, errorService] = await enviarSolicitudAmistadService(
      rutEmisor,
      rutReceptor,
      mensaje
    );

    if (errorService) {
      return handleErrorClient(res, 400, errorService);
    }

    // Crear notificación para el receptor
    try {
      await crearNotificacionService({
        tipo: 'solicitud_amistad',
        titulo: 'Nueva solicitud de amistad',
        mensaje: `${req.user.nombreCompleto || rutEmisor} te ha enviado una solicitud de amistad`,
        rutReceptor: rutReceptor,
        rutEmisor: rutEmisor,
        datos: {
          solicitudId: solicitud.id,
          mensaje: mensaje
        }
      });
      console.log(`✅ Notificación de solicitud de amistad enviada a ${rutReceptor}`);
      
      // Enviar notificación WebSocket en tiempo real
      const getIo = req.app.get('io');
      const io = getIo ? getIo() : null;
      
      if (io) {
        await WebSocketNotificationService.enviarSolicitudAmistad(
          io,
          rutReceptor,
          req.user.nombreCompleto || req.user.nombre || rutEmisor,
          rutEmisor
        );
      } else {
        console.warn(`⚠️ Socket.io no está disponible en el controlador`);
      }
    } catch (notifError) {
      console.warn("⚠️ Error al crear notificación:", notifError);
      // No fallar la operación principal por error en notificación
    }

    handleSuccess(res, 201, "Solicitud de amistad enviada correctamente", solicitud);
  } catch (error) {
    console.error("Error en enviarSolicitudAmistad:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function responderSolicitudAmistad(req, res) {
  try {
    const { error } = respuestaSolicitudValidation.validate(req.body);
    
    if (error) {
      return handleErrorClient(res, 400, error.details[0].message);
    }

    const { idSolicitud } = req.params;
    const { respuesta } = req.body;
    const rutReceptor = req.user.rut;

    const [resultado, errorService] = await responderSolicitudAmistadService(
      parseInt(idSolicitud),
      rutReceptor,
      respuesta
    );

    if (errorService) {
      return handleErrorClient(res, 400, errorService);
    }

    // Crear notificación para el emisor de la solicitud
    if (resultado && resultado.rutEmisor) {
      try {
        const tipoNotificacion = respuesta === "aceptada" ? 'amistad_aceptada' : 'amistad_rechazada';
        const titulo = respuesta === "aceptada" ? '¡Nueva amistad!' : 'Solicitud rechazada';
        const mensaje = respuesta === "aceptada" 
          ? `${req.user.nombreCompleto || rutReceptor} aceptó tu solicitud de amistad. ¡Ahora son amigos!`
          : `${req.user.nombreCompleto || rutReceptor} rechazó tu solicitud de amistad`;

        await crearNotificacionService({
          tipo: tipoNotificacion,
          titulo: titulo,
          mensaje: mensaje,
          rutReceptor: resultado.rutEmisor,
          rutEmisor: rutReceptor,
          datos: {
            solicitudId: idSolicitud,
            respuesta: respuesta
          }
        });
        console.log(`✅ Notificación de ${respuesta} enviada a ${resultado.rutEmisor}`);
        
        // Enviar notificación WebSocket en tiempo real
        const getIo = req.app.get('io');
        const io = getIo ? getIo() : null;
        
        if (io) {
          const nombreReceptor = req.user.nombreCompleto || req.user.nombre || rutReceptor;
          
          if (respuesta === "aceptada") {
            await WebSocketNotificationService.enviarAmistadAceptada(
              io,
              resultado.rutEmisor,
              nombreReceptor,
              rutReceptor
            );
          } else {
            await WebSocketNotificationService.enviarAmistadRechazada(
              io,
              resultado.rutEmisor,
              nombreReceptor,
              rutReceptor
            );
          }
        }
      } catch (notifError) {
        console.warn("⚠️ Error al crear notificación:", notifError);
        // No fallar la operación principal por error en notificación
      }
    }

    const mensaje = respuesta === "aceptada" 
      ? "Solicitud aceptada. ¡Ahora son amigos!"
      : "Solicitud rechazada";

    handleSuccess(res, 200, mensaje, resultado);
  } catch (error) {
    console.error("Error en responderSolicitudAmistad:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function obtenerSolicitudesPendientes(req, res) {
  try {
    const rutUsuario = req.user.rut; // Cambio de req.rut a req.user.rut

    const [solicitudes, error] = await obtenerSolicitudesPendientesService(rutUsuario);

    if (error) {
      return handleErrorClient(res, 400, error);
    }

    handleSuccess(res, 200, "Solicitudes pendientes obtenidas correctamente", solicitudes);
  } catch (error) {
    console.error("Error en obtenerSolicitudesPendientes:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function obtenerAmigos(req, res) {
  try {
    const rutUsuario = req.user.rut; // Cambio de req.rut a req.user.rut

    const [amigos, error] = await obtenerAmigosService(rutUsuario);

    if (error) {
      return handleErrorClient(res, 400, error);
    }

    handleSuccess(res, 200, "Amigos obtenidos correctamente", amigos);
  } catch (error) {
    console.error("Error en obtenerAmigos:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function eliminarAmistad(req, res) {
  try {
    const { error } = rutValidation.validate({ rut: req.params.rutAmigo });
    
    if (error) {
      return handleErrorClient(res, 400, error.details[0].message);
    }

    const { rutAmigo } = req.params;
    const rutUsuario = req.user.rut; // Cambio de req.rut a req.user.rut

    const [resultado, errorService] = await eliminarAmistadService(rutUsuario, rutAmigo);

    if (errorService) {
      return handleErrorClient(res, 400, errorService);
    }

    handleSuccess(res, 200, "Amistad eliminada correctamente", resultado);
  } catch (error) {
    console.error("Error en eliminarAmistad:", error);
    handleErrorServer(res, 500, error.message);
  }
}
