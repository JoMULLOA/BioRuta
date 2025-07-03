"use strict";
import {
  enviarSolicitudAmistadService,
  responderSolicitudAmistadService,
  obtenerSolicitudesPendientesService,
  obtenerAmigosService,
  eliminarAmistadService
} from "../services/amistad.service.js";
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
    const rutEmisor = req.user.rut; // Cambio de req.rut a req.user.rut

    const [solicitud, errorService] = await enviarSolicitudAmistadService(
      rutEmisor,
      rutReceptor,
      mensaje
    );

    if (errorService) {
      return handleErrorClient(res, 400, errorService);
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
    const rutReceptor = req.user.rut; // Cambio de req.rut a req.user.rut

    const [resultado, errorService] = await responderSolicitudAmistadService(
      parseInt(idSolicitud),
      rutReceptor,
      respuesta
    );

    if (errorService) {
      return handleErrorClient(res, 400, errorService);
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
