"use strict";
import Joi from "joi";

// Validación para crear/actualizar vehículo
export const vehiculoBodyValidation = Joi.object({
  patente: Joi.string()
    .min(6)
    .max(6)
    .pattern(/^[A-Z]{2}\d{4}$|^[A-Z]{4}\d{2}$/)
    .messages({
      "string.empty": "La patente no puede estar vacía.",
      "string.base": "La patente debe ser de tipo string.",
      "string.min": "La patente debe tener exactamente 6 caracteres.",
      "string.max": "La patente debe tener exactamente 6 caracteres.",
      "string.pattern.base": "Formato de patente inválido. Debe ser AA1234 o AAAA12.",
    }),
  modelo: Joi.string()
    .min(3)
    .max(100)
    .messages({
      "string.empty": "El modelo no puede estar vacío.",
      "string.base": "El modelo debe ser de tipo string.",
      "string.min": "El modelo debe tener al menos 3 caracteres.",
      "string.max": "El modelo debe tener máximo 100 caracteres.",
    }),
  color: Joi.string()
    .min(2)
    .max(50)
    .messages({
      "string.empty": "El color no puede estar vacío.",
      "string.base": "El color debe ser de tipo string.",
      "string.min": "El color debe tener al menos 2 caracteres.",
      "string.max": "El color debe tener máximo 50 caracteres.",
    }),
  nro_asientos: Joi.number()
    .integer()
    .min(2)
    .max(9)
    .messages({
      "number.base": "El número de asientos debe ser un número.",
      "number.integer": "El número de asientos debe ser un número entero.",
      "number.min": "El número de asientos debe ser al menos 2.",
      "number.max": "El número de asientos debe ser máximo 9.",
    }),
  documentacion: Joi.string()
    .min(5)
    .max(500)
    .messages({
      "string.empty": "La documentación no puede estar vacía.",
      "string.base": "La documentación debe ser de tipo string.",
      "string.min": "La documentación debe tener al menos 5 caracteres.",
      "string.max": "La documentación debe tener máximo 500 caracteres.",
    }),
})
  .required()
  .messages({
    "object.unknown": "No se permiten propiedades adicionales.",
  });

// Validación para consulta por patente
export const vehiculoQueryValidation = Joi.object({
  patente: Joi.string()
    .min(6)
    .max(6)
    .pattern(/^[A-Z]{2}\d{4}$|^[A-Z]{4}\d{2}$/)
    .messages({
      "string.empty": "La patente no puede estar vacía.",
      "string.base": "La patente debe ser de tipo string.",
      "string.min": "La patente debe tener exactamente 6 caracteres.",
      "string.max": "La patente debe tener exactamente 6 caracteres.",
      "string.pattern.base": "Formato de patente inválido. Debe ser AA1234 o AAAA12.",
    }),
})
  .unknown(false)
  .messages({
    "object.unknown": "No se permiten propiedades adicionales.",
  });
