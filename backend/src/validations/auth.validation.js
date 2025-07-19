"use strict";
import Joi from "joi";

const domainEmailValidator = (value, helper) => {
  const allowedDomains = ["@alumnos.ubiobio.cl", "@ubiobio.cl"]; // Lista de dominios permitidos

  const isValidDomain = allowedDomains.some(domain => value.endsWith(domain));
  if (!isValidDomain) {
    return helper.message(
      `El correo electrónico debe ser de uno de los siguientes dominios: ${allowedDomains.join(", ")}`
    );
  }
  return value;
};

export const authValidation = Joi.object({
  email: Joi.string()
    .min(10)
    .max(50)
    .email()
    .required()
    .messages({
      "string.empty": "El correo electrónico no puede estar vacío.",
      "any.required": "El correo electrónico es obligatorio.",
      "string.base": "El correo electrónico debe ser de tipo texto.",
      "string.min": "El correo electrónico debe tener al menos 10 caracteres.",
      "string.max": "El correo electrónico debe tener como máximo 50 caracteres.",
    })
    .custom(domainEmailValidator, "Validación dominio email"),
  password: Joi.string()
    .min(8)
    .max(26)
    .pattern(/^[a-zA-Z0-9]+$/)
    .required()
    .messages({
      "string.empty": "La contraseña no puede estar vacía.",
      "any.required": "La contraseña es obligatoria.",
      "string.base": "La contraseña debe ser de tipo texto.",
      "string.min": "La contraseña debe tener al menos 8 caracteres.",
      "string.max": "La contraseña debe tener como máximo 26 caracteres.",
      "string.pattern.base": "La contraseña solo puede contener letras y números.",
    }),
}).unknown(false).messages({
  "object.unknown": "No se permiten propiedades adicionales.",
});

export const registerValidation = Joi.object({
  nombreCompleto: Joi.string()
    .min(10)
    .max(50)
    .pattern(/^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$/)
    .required()
    .messages({
      "string.empty": "El nombre completo no puede estar vacío.",
      "any.required": "El nombre completo es obligatorio.",
      "string.base": "El nombre completo debe ser de tipo texto.",
      "string.min": "El nombre completo debe tener al menos 10 caracteres.",
      "string.max": "El nombre completo debe tener como máximo 50 caracteres.",
      "string.pattern.base": "El nombre completo solo puede contener letras y espacios.",
    }),
  rut: Joi.string()
    .min(9)
    .max(12)
    .required()
    .pattern(/^(?:(?:[1-9]\d{0}|[1-2]\d{1})(\.\d{3}){2}|[1-9]\d{6}|[1-2]\d{7}|29\.999\.999|29999999)-[\dkK]$/)
    .messages({
      "string.empty": "El rut no puede estar vacío.",
      "string.base": "El rut debe ser de tipo string.",
      "string.min": "El rut debe tener como mínimo 9 caracteres.",
      "string.max": "El rut debe tener como máximo 12 caracteres.",
      "string.pattern.base": "Formato rut inválido, debe ser xx.xxx.xxx-x o xxxxxxxx-x.",
    }),
  email: Joi.string()
    .min(15)
    .max(50)
    .email()
    .required()
    .messages({
      "string.empty": "El correo electrónico no puede estar vacío.",
      "any.required": "El correo electrónico es obligatorio.",
      "string.base": "El correo electrónico debe ser de tipo texto.",
      "string.min": "El correo electrónico debe tener al menos 15 caracteres.",
      "string.max": "El correo electrónico debe tener como máximo 50 caracteres.",
    })
    .custom(domainEmailValidator, "Validación dominio email"),
  rol: Joi.string()
    .valid("estudiante")
    .required()
    .messages({
      "string.empty": "El rol no puede estar vacío.",
      "any.required": "El rol es obligatorio.",
      "string.base": "El rol debe ser de tipo texto.",
      "any.only": "El rol debe ser 'estudiante'.",
    }),
  password: Joi.string()
    .min(8)
    .max(26)
    .pattern(/^[a-zA-Z0-9]+$/)
    .required()
    .messages({
      "string.empty": "La contraseña no puede estar vacía.",
      "any.required": "La contraseña es obligatoria.",
      "string.base": "La contraseña debe ser de tipo texto.",
      "string.min": "La contraseña debe tener al menos 8 caracteres.",
      "string.max": "La contraseña debe tener como máximo 26 caracteres.",
      "string.pattern.base": "La contraseña solo puede contener letras y números.",
    }),
  carrera: Joi.string()
    .min(5)
    .max(50)
    .required()
    .messages({
      "string.empty": "La carrera no puede estar vacía.",
      "any.required": "La carrera es obligatoria.",
      "string.base": "La carrera debe ser de tipo texto.",
      "string.min": "La carrera debe tener al menos 5 caracteres.",
      "string.max": "La carrera debe tener como máximo 50 caracteres.",
    }),
  fechaNacimiento: Joi.date()
    .max('now')
    .min('1900-01-01')
    .required()
    .messages({
      "date.base": "La fecha de nacimiento debe ser una fecha válida.",
      "date.max": "La fecha de nacimiento no puede ser una fecha futura.",
      "date.min": "La fecha de nacimiento debe ser posterior a 1900.",
      "any.required": "La fecha de nacimiento es obligatoria.",
    }),
  genero: Joi.string()
    .valid("masculino", "femenino", "no_binario", "prefiero_no_decir")
    .required()
    .messages({
      "string.empty": "El género no puede estar vacío.",
      "any.required": "El género es obligatorio.",
      "string.base": "El género debe ser de tipo texto.",
      "any.only": "El género debe ser uno de: masculino, femenino, no_binario, prefiero_no_decir.",
    }),
}).unknown(false).messages({
  "object.unknown": "No se permiten propiedades adicionales.",
});