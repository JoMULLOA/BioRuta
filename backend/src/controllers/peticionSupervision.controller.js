import * as peticionSupervisionService from "../services/peticionSupervision.service.js";

/**
 * Crear una nueva petición de supervisión
 * POST /api/peticiones-supervision
 */
export const crearPeticion = async (req, res) => {
  try {
    const { motivo, mensaje, prioridad = "media" } = req.body;
    const rutUsuario = req.user.rut;

    if (!mensaje || mensaje.trim() === "") {
      return res.status(400).json({
        success: false,
        message: "El mensaje es requerido",
      });
    }

    const resultado = await peticionSupervisionService.crearPeticionSupervision(rutUsuario, motivo, mensaje, prioridad);

    res.status(201).json(resultado);

  } catch (error) {
    console.error("Error en crearPeticion:", error.message);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

/**
 * Obtener todas las peticiones de supervisión (solo administradores)
 * GET /api/peticiones-supervision
 */
export const obtenerPeticiones = async (req, res) => {
  try {
    // Verificar que el usuario es administrador
    if (req.user.rol !== "administrador") {
      return res.status(403).json({
        success: false,
        message: "No tienes permisos para acceder a esta información",
      });
    }

    const { estado } = req.query;
    const resultado = await peticionSupervisionService.obtenerPeticionesSupervision(estado);

    res.status(200).json(resultado);

  } catch (error) {
    console.error("Error en obtenerPeticiones:", error.message);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

/**
 * Responder a una petición de supervisión (solo administradores)
 * PUT /api/peticiones-supervision/:id/responder
 */
export const responderPeticion = async (req, res) => {
  try {
    // Verificar que el usuario es administrador
    if (req.user.rol !== "administrador") {
      return res.status(403).json({
        success: false,
        message: "No tienes permisos para realizar esta acción",
      });
    }

    const { id } = req.params;
    const { accion, respuesta } = req.body;
    const rutAdministrador = req.user.rut;

    if (!accion || !["aceptar", "denegar"].includes(accion)) {
      return res.status(400).json({
        success: false,
        message: "La acción debe ser 'aceptar' o 'denegar'",
      });
    }

    const resultado = await peticionSupervisionService.responderPeticionSupervision(
      parseInt(id),
      rutAdministrador,
      accion,
      respuesta
    );

    res.status(200).json(resultado);

  } catch (error) {
    console.error("Error en responderPeticion:", error.message);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

/**
 * Obtener peticiones del usuario actual
 * GET /api/peticiones-supervision/mis-peticiones
 */
export const obtenerMisPeticiones = async (req, res) => {
  try {
    const rutUsuario = req.user.rut;
    const resultado = await peticionSupervisionService.obtenerPeticionesUsuario(rutUsuario);

    res.status(200).json(resultado);

  } catch (error) {
    console.error("Error en obtenerMisPeticiones:", error.message);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

/**
 * Eliminar una petición de supervisión
 * DELETE /api/peticiones-supervision/:id
 */
export const eliminarPeticion = async (req, res) => {
  try {
    const { id } = req.params;
    const rutUsuario = req.user.rut;

    const resultado = await peticionSupervisionService.eliminarPeticionSupervision(parseInt(id), rutUsuario);

    res.status(200).json(resultado);

  } catch (error) {
    console.error("Error en eliminarPeticion:", error.message);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

/**
 * Obtener estadísticas de peticiones (solo administradores)
 * GET /api/peticiones-supervision/estadisticas
 */
export const obtenerEstadisticas = async (req, res) => {
  try {
    // Verificar que el usuario es administrador
    if (req.user.rol !== "administrador") {
      return res.status(403).json({
        success: false,
        message: "No tienes permisos para acceder a esta información",
      });
    }

    const resultado = await peticionSupervisionService.obtenerEstadisticasPeticiones();

    res.status(200).json(resultado);

  } catch (error) {
    console.error("Error en obtenerEstadisticas:", error.message);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

/**
 * PUT /api/peticiones-supervision/:id/solucionada
 * Marcar una petición como solucionada
 */
export async function marcarComoSolucionada(req, res) {
  try {
    const { id } = req.params;
    const rutAdministrador = req.user.rut;

    const resultado = await peticionSupervisionService.marcarPeticionComoSolucionada(
      parseInt(id),
      rutAdministrador
    );

    res.status(200).json(resultado);
  } catch (error) {
    console.error("Error en marcarComoSolucionada:", error.message);
    res.status(400).json({
      success: false,
      message: error.message,
    });
  }
}

/**
 * GET /api/peticiones-supervision/verificar-activa
 * Verificar si el usuario tiene una petición activa
 */
export async function verificarPeticionActiva(req, res) {
  try {
    const rutUsuario = req.user.rut;

    const peticionActiva = await peticionSupervisionService.verificarPeticionActiva(rutUsuario);

    res.status(200).json({
      success: true,
      data: peticionActiva,
      tieneActiva: peticionActiva !== null,
    });
  } catch (error) {
    console.error("Error en verificarPeticionActiva:", error.message);
    res.status(400).json({
      success: false,
      message: error.message,
    });
  }
}

/**
 * GET /api/peticiones-supervision/verificar-pendiente
 * Verificar si el usuario tiene una petición pendiente
 */
export async function verificarPeticionPendiente(req, res) {
  try {
    const rutUsuario = req.user.rut;

    const peticionPendiente = await peticionSupervisionService.verificarPeticionPendiente(rutUsuario);

    res.status(200).json({
      success: true,
      data: peticionPendiente,
      tienePendiente: peticionPendiente !== null,
    });
  } catch (error) {
    console.error("Error en verificarPeticionPendiente:", error.message);
    res.status(400).json({
      success: false,
      message: error.message,
    });
  }
}