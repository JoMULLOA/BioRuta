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
  tipo: Joi.string()
    .valid("sedan", "hatchback", "suv", "pickup", "furgon", "camioneta", "coupe", "convertible", "otro")
    .messages({
      "string.empty": "El tipo de vehículo no puede estar vacío.",
      "string.base": "El tipo debe ser de tipo string.",
      "any.only": "El tipo debe ser uno de: sedan, hatchback, suv, pickup, furgon, camioneta, coupe, convertible, otro.",
    }),
  marca: Joi.string()
    .min(2)
    .max(50)
    .messages({
      "string.empty": "La marca no puede estar vacía.",
      "string.base": "La marca debe ser de tipo string.",
      "string.min": "La marca debe tener al menos 2 caracteres.",
      "string.max": "La marca debe tener máximo 50 caracteres.",
    }),
  modelo: Joi.string()
    .min(2)
    .max(50)
    .messages({
      "string.empty": "El modelo no puede estar vacío.",
      "string.base": "El modelo debe ser de tipo string.",
      "string.min": "El modelo debe tener al menos 2 caracteres.",
      "string.max": "El modelo debe tener máximo 50 caracteres.",
    }),
  año: Joi.number()
    .integer()
    .min(1990)
    .max(new Date().getFullYear() + 1)
    .messages({
      "number.base": "El año debe ser un número.",
      "number.integer": "El año debe ser un número entero.",
      "number.min": "El año debe ser a partir de 1990.",
      "number.max": `El año debe ser máximo ${new Date().getFullYear() + 1}.`,
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
  tipoCombustible: Joi.string()
    .valid("bencina", "petroleo", "electrico", "hibrido", "gas")
    .default("bencina")
    .messages({
      "string.base": "El tipo de combustible debe ser de tipo string.",
      "any.only": "El tipo de combustible debe ser uno de: bencina, petroleo, electrico, hibrido, gas.",
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
