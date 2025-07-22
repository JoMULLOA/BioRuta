"use strict";
import { crearNotificacionService } from "../services/notificacion.service.js";

export async function crearNotificacionSolicitudViaje(datosViaje, rutSolicitante, nombreSolicitante, rutConductor) {
  try {
    const datos = {
      tipo: "solicitud_viaje",
      titulo: "Nueva solicitud de viaje",
      mensaje: `${nombreSolicitante} quiere unirse a tu viaje`,
      rutReceptor: rutConductor,
      rutEmisor: rutSolicitante,
      viajeId: datosViaje.id,
      datos: {
        viajeId: datosViaje.id,
        solicitanteId: rutSolicitante,
        solicitanteNombre: nombreSolicitante,
        origen: datosViaje.origen.nombre,
        destino: datosViaje.destino.nombre,
        precio: datosViaje.precio,
        fechaViaje: datosViaje.fechaIda,
        horaViaje: datosViaje.horaIda
      }
    };

    const [notificacion, error] = await crearNotificacionService(datos);
    
    if (error) {
      console.error("Error al crear notificación de solicitud de viaje:", error);
      return [null, error];
    }

    return [notificacion, null];
  } catch (error) {
    console.error("Error en crearNotificacionSolicitudViaje:", error);
    return [null, "Error al crear la notificación"];
  }
}

export async function crearNotificacionViajeConfirmado(datosViaje, rutPasajero, nombreConductor) {
  try {
    const datos = {
      tipo: "viaje_confirmado",
      titulo: "Viaje confirmado",
      mensaje: `${nombreConductor} ha aceptado tu solicitud de viaje`,
      rutReceptor: rutPasajero,
      rutEmisor: null, // Sistema
      viajeId: datosViaje.id,
      datos: {
        viajeId: datosViaje.id,
        conductorNombre: nombreConductor,
        origen: datosViaje.origen.nombre,
        destino: datosViaje.destino.nombre
      }
    };

    const [notificacion, error] = await crearNotificacionService(datos);
    
    if (error) {
      console.error("Error al crear notificación de viaje confirmado:", error);
      return [null, error];
    }

    return [notificacion, null];
  } catch (error) {
    console.error("Error en crearNotificacionViajeConfirmado:", error);
    return [null, "Error al crear la notificación"];
  }
}

export async function crearNotificacionViajeRechazado(datosViaje, rutPasajero, nombreConductor) {
  try {
    const datos = {
      tipo: "viaje_rechazado",
      titulo: "Solicitud rechazada",
      mensaje: `${nombreConductor} ha rechazado tu solicitud de viaje`,
      rutReceptor: rutPasajero,
      rutEmisor: null, // Sistema
      viajeId: datosViaje.id,
      datos: {
        viajeId: datosViaje.id,
        conductorNombre: nombreConductor,
        origen: datosViaje.origen.nombre,
        destino: datosViaje.destino.nombre
      }
    };

    const [notificacion, error] = await crearNotificacionService(datos);
    
    if (error) {
      console.error("Error al crear notificación de viaje rechazado:", error);
      return [null, error];
    }

    return [notificacion, null];
  } catch (error) {
    console.error("Error en crearNotificacionViajeRechazado:", error);
    return [null, "Error al crear la notificación"];
  }
}
