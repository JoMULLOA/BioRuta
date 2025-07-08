"use strict";
import Joi from "joi";

export const crearPagoValidation = Joi.object({
  viajeId: Joi.string()
    .required()
    .messages({
      "string.base": "El ID del viaje debe ser texto",
      "any.required": "El ID del viaje es obligatorio",
    }),
  montoTotal: Joi.number()
    .positive()
    .precision(2)
    .required()
    .messages({
      "number.base": "El monto total debe ser un número",
      "number.positive": "El monto total debe ser positivo",
      "any.required": "El monto total es obligatorio",
    }),
  descripcion: Joi.string()
    .max(255)
    .optional()
    .messages({
      "string.base": "La descripción debe ser texto",
      "string.max": "La descripción no puede exceder 255 caracteres",
    }),
  items: Joi.array()
    .items(
      Joi.object({
        title: Joi.string().required(),
        quantity: Joi.number().integer().positive().required(),
        unit_price: Joi.number().positive().required(),
        currency_id: Joi.string().default("CLP"),
      })
    )
    .optional()
    .messages({
      "array.base": "Los items deben ser un arreglo",
    }),
}).messages({
  "object.unknown": "No se permiten campos adicionales",
});

export const paymentIdValidation = Joi.object({
  paymentId: Joi.string()
    .required()
    .messages({
      "string.base": "El ID del pago debe ser texto",
      "any.required": "El ID del pago es obligatorio",
    }),
});

export const pagoIdValidation = Joi.object({
  pagoId: Joi.number()
    .integer()
    .positive()
    .required()
    .messages({
      "number.base": "El ID del pago debe ser un número",
      "number.integer": "El ID del pago debe ser un número entero",
      "number.positive": "El ID del pago debe ser positivo",
      "any.required": "El ID del pago es obligatorio",
    }),
});
