"use strict";
import Joi from "joi";

/**
 * Validador personalizado para números de teléfono chilenos
 */
const phoneValidator = (value, helper) => {
  // Formato chileno: +56XXXXXXXXX (9 dígitos después del +56)
  // También acepta 9XXXXXXXX (8 dígitos después del 9)
  const phoneRegex = /^(\+56|56)?[2-9]\d{8}$/;
  
  if (!phoneRegex.test(value.replace(/\s/g, ''))) {
    return helper.message("El número de teléfono debe ser válido (formato chileno)");
  }
  return value;
};

/**
 * Validación para crear/actualizar contacto de emergencia
 */
export const contactoEmergenciaBodyValidation = Joi.object({
  nombre: Joi.string()
    .min(2)
    .max(255)
    .pattern(/^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$/)
    .required()
    .messages({
      "string.empty": "El nombre no puede estar vacío.",
      "string.base": "El nombre debe ser de tipo string.",
      "string.min": "El nombre debe tener como mínimo 2 caracteres.",
      "string.max": "El nombre debe tener como máximo 255 caracteres.",
      "string.pattern.base": "El nombre solo puede contener letras y espacios.",
      "any.required": "El nombre es obligatorio.",
    }),

  telefono: Joi.string()
    .custom(phoneValidator)
    .required()
    .messages({
      "string.empty": "El teléfono no puede estar vacío.",
      "string.base": "El teléfono debe ser de tipo string.",
      "any.required": "El teléfono es obligatorio.",
    }),

  email: Joi.string()
    .email()
    .max(255)
    .optional()
    .allow('')
    .messages({
      "string.email": "El email debe tener un formato válido.",
      "string.max": "El email debe tener como máximo 255 caracteres.",
    }),
});

/**
 * Validación para consultas por ID
 */
export const contactoEmergenciaQueryValidation = Joi.object({
  id: Joi.string()
    .uuid()
    .required()
    .messages({
      "string.empty": "El ID no puede estar vacío.",
      "string.base": "El ID debe ser de tipo string.",
      "string.uuid": "El ID debe ser un UUID válido.",
      "any.required": "El ID es obligatorio.",
    }),
});
