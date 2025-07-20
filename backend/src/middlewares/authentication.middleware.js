"use strict";
import passport from "passport";
import {
  handleErrorClient,
  handleErrorServer,
} from "../handlers/responseHandlers.js";
import jwt from "jsonwebtoken"; // Aunque no lo uses directamente en authenticateJwt, es bueno tenerlo

export function authenticateJwt(req, res, next) {
  // --- ¡LOGS CRUCIALES AQUÍ! ---
  console.log("BACKEND DEBUG: authenticateJwt middleware llamado.");
  console.log("BACKEND DEBUG: Header Authorization COMPLETO recibido por authenticateJwt:", req.headers.authorization);

  // Passport.js se encarga de la extracción y verificación del token
  passport.authenticate("jwt", { session: false }, (err, user, info) => {
    if (err) {
      console.error("BACKEND DEBUG: Error general de Passport.js:", err); // Log el error completo de Passport
      return handleErrorServer(
        res,
        500,
        "Error de autenticación en el servidor"
      );
    }

    if (!user) {
      // BACKEND DEBUG: Usuario NO autenticado. Detalles del fallo (info)
      console.log("BACKEND DEBUG: Usuario NO autenticado por Passport.");
      console.log("BACKEND DEBUG: Info de fallo de Passport:", info); // Aquí veremos el "jwt malformed" si viene de Passport

      let errorMessage = "No tienes permiso para acceder a este recurso";
      let details = {};

      if (info) {
        if (info.message === "No auth token") {
            errorMessage = "No se proporcionó token de autenticación.";
            details.info = info.message;
        } else if (info.message === "jwt malformed" || info.message === "invalid token" || info.message === "jwt expired") {
            errorMessage = "Token inválido o caducado.";
            details.info = info.message;
        } else {
            details.info = info.message;
        }
      } else {
          details.info = "No se encontró el usuario o la información del error es nula.";
      }

      return handleErrorClient(
        res,
        401,
        errorMessage,
        details
      );
    }

    // BACKEND DEBUG: Usuario autenticado exitosamente
    console.log("BACKEND DEBUG: Usuario autenticado por Passport:", user.email || user.rut); // Log el email o rut del usuario
    req.user = user;
    req.rut = user.rut; // Asignar el RUT directamente para facilitar su uso en controladores
    next();
  })(req, res, next);
}

// Esta función 'verificarToken' parece no estar en uso o en la ruta incorrecta si el error viene de authenticateJwt
// Si no la estás usando en ninguna ruta (como /api/users), puedes ignorar los logs para esta función por ahora.
export function verificarToken(req, res, next) {
  const tokenHeader = req.headers["authorization"];

  if (!tokenHeader) {
    return res.status(401).json({ mensaje: "Token no proporcionado" });
  }

  try {
    const token = tokenHeader.split(" ")[1];
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.usuario = payload;
    next();
  } catch (error) {
    return res.status(403).json({ mensaje: "Token inválido o expirado" });
  }
}
