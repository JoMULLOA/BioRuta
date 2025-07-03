"use strict";
import {
  obtenerNotificacionesService,
  contarNotificacionesPendientesService
} from "../services/notificacion.service.js";
import {
  handleErrorClient,
  handleErrorServer,
  handleSuccess,
} from "../handlers/responseHandlers.js";

export async function obtenerNotificaciones(req, res) {
  try {
    const rutUsuario = req.user.rut; // Cambio de req.rut a req.user.rut

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
    const rutUsuario = req.user.rut; // Cambio de req.rut a req.user.rut

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
