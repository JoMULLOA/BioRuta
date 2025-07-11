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
      return handleErrorServer(res, 400, `Errores de validación: ${errorMessages.join(', ')}`);
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
      return handleErrorServer(res, 400, `Errores de validación en parámetros: ${errorMessages.join(', ')}`);
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
      return handleErrorServer(res, 400, `Errores de validación en parámetros de URL: ${errorMessages.join(', ')}`);
    }
    
    req.params = value; // Usar los valores validados y limpios
    next();
  };
}

/**
 * Middleware genérico de validación que puede validar body, query o params
 * @param {Object} schema - Esquema de validación Joi
 * @param {string} target - 'body', 'query', o 'params' (por defecto 'body')
 */
export function validationMiddleware(schema, target = 'body') {
  return (req, res, next) => {
    let dataToValidate;
    
    switch (target) {
      case 'query':
        dataToValidate = req.query;
        break;
      case 'params':
        dataToValidate = req.params;
        break;
      case 'body':
      default:
        dataToValidate = req.body;
        break;
    }

    const { error, value } = schema.validate(dataToValidate, { 
      abortEarly: false,
      stripUnknown: true 
    });
    
    if (error) {
      const errorMessages = error.details.map(detail => detail.message);
      return handleErrorServer(res, 400, `Errores de validación en ${target}: ${errorMessages.join(', ')}`);
    }
    
    // Asignar los valores validados y limpios de vuelta al request
    switch (target) {
      case 'query':
        req.query = value;
        break;
      case 'params':
        req.params = value;
        break;
      case 'body':
      default:
        req.body = value;
        break;
    }
    
    next();
  };
}
