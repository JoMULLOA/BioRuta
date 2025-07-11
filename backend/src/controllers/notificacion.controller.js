"use strict";
import {
  obtenerNotificacionesService,
  contarNotificacionesPendientesService,
  marcarComoLeidaService,
  responderSolicitudViajeService
} from "../services/notificacion.service.js";
import {
  handleErrorClient,
  handleErrorServer,
  handleSuccess,
} from "../handlers/responseHandlers.js";

export async function obtenerNotificaciones(req, res) {
  try {
    const rutUsuario = req.user.rut;

    const [notificaciones, error] = await obtenerNotificacionesService(rutUsuario);

    if (error) {
      return handleErrorClient(res, 400, error);
    }

    handleSuccess(res, 200, "Notificaciones obtenidas correctamente", notificaciones);
  } catch (error) {
    console.error("Error en obtenerNotificaciones:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function contarNotificacionesPendientes(req, res) {
  try {
    const rutUsuario = req.user.rut;

    const [count, error] = await contarNotificacionesPendientesService(rutUsuario);

    if (error) {
      return handleErrorClient(res, 400, error);
    }

    handleSuccess(res, 200, "Conteo de notificaciones obtenido correctamente", { count });
  } catch (error) {
    console.error("Error en contarNotificacionesPendientes:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function marcarComoLeida(req, res) {
  try {
    const { id } = req.params;
    const rutUsuario = req.user.rut;

    const [notificacion, error] = await marcarComoLeidaService(id, rutUsuario);

    if (error) {
      return handleErrorClient(res, 400, error);
    }

    handleSuccess(res, 200, "Notificación marcada como leída", notificacion);
  } catch (error) {
    console.error("Error en marcarComoLeida:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function responderSolicitudViaje(req, res) {
  try {
    const { id } = req.params;
    const { aceptar } = req.body;
    const rutUsuario = req.user.rut;

    const [resultado, error] = await responderSolicitudViajeService(id, aceptar, rutUsuario);

    if (error) {
      return handleErrorClient(res, 400, error);
    }

    handleSuccess(res, 200, resultado.mensaje, resultado);
  } catch (error) {
    console.error("Error en responderSolicitudViaje:", error);
    handleErrorServer(res, 500, error.message);
  }
}
