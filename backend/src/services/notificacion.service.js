"use strict";
import { AppDataSource } from "../config/configDb.js";
import SolicitudAmistad from "../entity/solicitudAmistad.entity.js";

export async function obtenerNotificacionesService(rutUsuario) {
  try {
    const solicitudRepository = AppDataSource.getRepository(SolicitudAmistad);

    // Obtener solicitudes pendientes recibidas
    const solicitudesPendientes = await solicitudRepository.find({
      where: {
        rutReceptor: rutUsuario,
        estado: "pendiente"
      },
      order: {
        fechaEnvio: "DESC"
      }
    });

    const notificaciones = solicitudesPendientes.map(solicitud => ({
      id: solicitud.id,
      tipo: "solicitud_amistad",
      titulo: "Nueva solicitud de amistad",
      mensaje: `${solicitud.emisor.nombreCompleto} te ha enviado una solicitud de amistad`,
      fecha: solicitud.fechaEnvio,
      leida: false,
      data: {
        idSolicitud: solicitud.id,
        rutEmisor: solicitud.rutEmisor,
        nombreEmisor: solicitud.emisor.nombreCompleto,
        mensaje: solicitud.mensaje
      }
    }));

    return [notificaciones, null];
  } catch (error) {
    console.error("Error en obtenerNotificacionesService:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function contarNotificacionesPendientesService(rutUsuario) {
  try {
    const solicitudRepository = AppDataSource.getRepository(SolicitudAmistad);

    const count = await solicitudRepository.count({
      where: {
        rutReceptor: rutUsuario,
        estado: "pendiente"
      }
    });

    return [count, null];
  } catch (error) {
    console.error("Error en contarNotificacionesPendientesService:", error);
    return [null, "Error interno del servidor"];
  }
}
