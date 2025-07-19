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

export const userQueryValidation = Joi.object({
  rut: Joi.string()
    .min(9)
    .max(12)
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
    .messages({
      "string.empty": "El correo electrónico no puede estar vacío.",
      "string.base": "El correo electrónico debe ser de tipo string.",
      // "string.email": "El correo electrónico debe finalizar en @gmail.cl.",
      "string.min":
        "El correo electrónico debe tener como mínimo 15 caracteres.",
      "string.max":
        "El correo electrónico debe tener como máximo 50 caracteres.",
    })
    .custom(domainEmailValidator, "Validación dominio email"),
})
  .or("rut", "email","carrera")
  .unknown(false)
  .messages({
    "object.unknown": "No se permiten propiedades adicionales.",
    "object.missing":
      "Debes proporcionar al menos un parámetro: email o rut.",
  });

export const userBodyValidation = Joi.object({
  nombreCompleto: Joi.string()
    .min(10)
    .max(50)
    .pattern(/^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$/)
    .messages({
      "string.empty": "El nombre completo no puede estar vacío.",
      "string.base": "El nombre completo debe ser de tipo string.",
      "string.min": "El nombre completo debe tener como mínimo 10 caracteres.",
      "string.max": "El nombre completo debe tener como máximo 50 caracteres.",
      "string.pattern.base":
        "El nombre completo solo puede contener letras y espacios.",
    }),
  email: Joi.string()
    .min(15)
    .max(50)
    .email()
    .messages({
      "string.empty": "El correo electrónico no puede estar vacío.",
      "string.base": "El correo electrónico debe ser de tipo string.",
      // "string.email": "El correo electrónico debe finalizar en @gmail.cl.",
      "string.min":
        "El correo electrónico debe tener como mínimo 15 caracteres.",
      "string.max":
        "El correo electrónico debe tener como máximo 50 caracteres.",
    })
    .custom(domainEmailValidator, "Validación dominio email"),
  password: Joi.string()
    .min(8)
    .max(26)
    .pattern(/^[a-zA-Z0-9]+$/)
    .messages({
      "string.empty": "La contraseña no puede estar vacía.",
      "string.base": "La contraseña debe ser de tipo string.",
      "string.min": "La contraseña debe tener como mínimo 8 caracteres.",
      "string.max": "La contraseña debe tener como máximo 26 caracteres.",
      "string.pattern.base":
        "La contraseña solo puede contener letras y números.",
    }),
  newPassword: Joi.string()
    .min(8)
    .max(26)
    .allow("")
    .pattern(/^[a-zA-Z0-9]+$/)
    .messages({
      "string.empty": "La nueva contraseña no puede estar vacía.",
      "string.base": "La nueva contraseña debe ser de tipo string.",
      "string.min": "La nueva contraseña debe tener como mínimo 8 caracteres.",
      "string.max": "La nueva contraseña debe tener como máximo 26 caracteres.",
      "string.pattern.base":
        "La nueva contraseña solo puede contener letras y números.",
    }),
  rut: Joi.string()
    .min(9)
    .max(12)
    .pattern(/^(?:(?:[1-9]\d{0}|[1-2]\d{1})(\.\d{3}){2}|[1-9]\d{6}|[1-2]\d{7}|29\.999\.999|29999999)-[\dkK]$/)
    .messages({
      "string.empty": "El rut no puede estar vacío.",
      "string.base": "El rut debe ser de tipo string.",
      "string.min": "El rut debe tener como mínimo 9 caracteres.",
      "string.max": "El rut debe tener como máximo 12 caracteres.",
      "string.pattern.base": "Formato rut inválido, debe ser xx.xxx.xxx-x o xxxxxxxx-x.",
    }),
  rol: Joi.string()
    .min(4)
    .max(15)
    .messages({
      "string.base": "El rol debe ser de tipo string.",
      "string.min": "El rol debe tener como mínimo 4 caracteres.",
      "string.max": "El rol debe tener como máximo 15 caracteres.",
    }),
  carrera: Joi.string()
    .min(2)
    .max(100)
    .allow("")
    .messages({
      "string.base": "La carrera debe ser de tipo string.",
      "string.min": "La carrera debe tener como mínimo 2 caracteres.",
      "string.max": "La carrera debe tener como máximo 100 caracteres.",
    }),
  descripcion: Joi.string()
    .min(0)
    .max(500)
    .allow("")
    .messages({
      "string.base": "La descripción debe ser de tipo string.",
      "string.max": "La descripción debe tener como máximo 500 caracteres.",
    }),
  fechaNacimiento: Joi.date()
    .max('now')
    .allow("")
    .allow(null)
    .messages({
      "date.base": "La fecha de nacimiento debe ser una fecha válida.",
      "date.max": "La fecha de nacimiento no puede ser en el futuro.",
    }),
  genero: Joi.string()
    .valid("masculino", "femenino", "no_binario", "prefiero_no_decir")
    .messages({
      "string.base": "El género debe ser de tipo string.",
      "any.only": "El género debe ser uno de: masculino, femenino, no_binario, prefiero_no_decir.",
    }),
})
  .or(
    "nombreCompleto",
    "email",
    "password",
    "newPassword",
    "rut",
    "rol",
    "carrera",
    "descripcion",
    "fechaNacimiento",
    "genero"
  )
  .unknown(false)
  .messages({
    "object.unknown": "No se permiten propiedades adicionales.",
    "object.missing":
      "Debes proporcionar al menos un campo: nombreCompleto, email, password, newPassword, rut, rol, carrera, descripcion, fechaNacimiento, genero.",
  });