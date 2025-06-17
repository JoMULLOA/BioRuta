"use strict";
import { handleErrorServer } from "../handlers/responseHandlers.js";

/**
 * Middleware para validar el body de las requests
 */
export function validateBody(schema) {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.body, { 
      abortEarly: false,
      stripUnknown: true 
    });
    
    if (error) {
      const errorMessages = error.details.map(detail => detail.message);
      return handleErrorServer(res, `Errores de validación: ${errorMessages.join(', ')}`);
    }
    
    req.body = value; // Usar los valores validados y limpios
    next();
  };
}

/**
 * Middleware para validar los query parameters
 */
export function validateQuery(schema) {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.query, { 
      abortEarly: false,
      stripUnknown: true 
    });
    
    if (error) {
      const errorMessages = error.details.map(detail => detail.message);
      return handleErrorServer(res, `Errores de validación en parámetros: ${errorMessages.join(', ')}`);
    }
    
    req.query = value; // Usar los valores validados y limpios
    next();
  };
}

/**
 * Middleware para validar los parámetros de la URL
 */
export function validateParams(schema) {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.params, { 
      abortEarly: false,
      stripUnknown: true 
    });
    
    if (error) {
      const errorMessages = error.details.map(detail => detail.message);
      return handleErrorServer(res, `Errores de validación en parámetros de URL: ${errorMessages.join(', ')}`);
    }
    
    req.params = value; // Usar los valores validados y limpios
    next();
  };
}
