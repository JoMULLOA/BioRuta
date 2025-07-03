"use strict";
import Joi from "joi";

export const solicitudAmistadBodyValidation = Joi.object({
  rutReceptor: Joi.string()
    .min(9)
    .max(12)
    .pattern(/^[0-9]{1,2}\.[0-9]{3}\.[0-9]{3}-[0-9kK]$/)
    .required()
    .messages({
      "string.empty": "El RUT del receptor no puede estar vacío.",
      "any.required": "El RUT del receptor es obligatorio.",
      "string.pattern.base": "El formato del RUT debe ser XX.XXX.XXX-X (ej: 12.345.678-9).",
      "string.min": "El RUT debe tener al menos 9 caracteres.",
      "string.max": "El RUT no puede tener más de 12 caracteres.",
    }),
  mensaje: Joi.string()
    .max(500)
    .optional()
    .messages({
      "string.max": "El mensaje no puede tener más de 500 caracteres.",
    }),
});

export const respuestaSolicitudValidation = Joi.object({
  respuesta: Joi.string()
    .valid("aceptada", "rechazada")
    .required()
    .messages({
      "any.only": "La respuesta debe ser 'aceptada' o 'rechazada'.",
      "any.required": "La respuesta es obligatoria.",
    }),
});

export const rutValidation = Joi.object({
  rut: Joi.string()
    .min(9)
    .max(12)
    .pattern(/^[0-9]{1,2}\.[0-9]{3}\.[0-9]{3}-[0-9kK]$/)
    .required()
    .messages({
      "string.empty": "El RUT no puede estar vacío.",
      "any.required": "El RUT es obligatorio.",
      "string.pattern.base": "El formato del RUT debe ser XX.XXX.XXX-X (ej: 12.345.678-9).",
      "string.min": "El RUT debe tener al menos 9 caracteres.",
      "string.max": "El RUT no puede tener más de 12 caracteres.",
    }),
});
