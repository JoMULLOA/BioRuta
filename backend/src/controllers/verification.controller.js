import { enviarCodigo, enviarCodigoR } from "../utils/mailer.js";
import { guardarCodigo, obtenerCodigo, eliminarCodigo } from "../utils/veritemp.js"; // funciones para guardar, obtener y eliminar el código
import { getUserGService } from "../services/user.service.js";
import Joi from "joi";
import { handleErrorClient } from "../handlers/responseHandlers.js";

// Validador de dominio de email (copiado de auth.validation.js)
const domainEmailValidator = (value, helper) => {
  const allowedDomains = ["@alumnos.ubiobio.cl", "@ubiobio.cl"];
  const isValidDomain = allowedDomains.some((domain) => value.endsWith(domain));
  if (!isValidDomain) {
    return helper.message(
      `El correo electrónico debe ser de uno de los siguientes dominios: ${allowedDomains.join(
        ", "
      )}`
    );
  }
  return value;
};

// Validación para el email en verificación
const emailValidation = Joi.object({
  email: Joi.string()
    .min(10)
    .max(50)
    .email()
    .required()
    .custom(domainEmailValidator, "Validación dominio email")
    .messages({
      "string.empty": "El correo electrónico no puede estar vacío.",
      "any.required": "El correo electrónico es obligatorio.",
      "string.base": "El correo electrónico debe ser de tipo texto.",
      "string.min": "El correo electrónico debe tener al menos 10 caracteres.",
      "string.max": "El correo electrónico debe tener como máximo 50 caracteres.",
      "string.email": "El correo electrónico debe tener un formato válido.",
    }),
});

export async function sendCode(req, res) {
  // VALIDAR EL EMAIL ANTES DE INTENTAR ENVIARLO
  const { error } = emailValidation.validate(req.body);
  if (error) {
    return handleErrorClient(res, 400, "Error de validación", error.message);
  }

  const { email } = req.body;
  const [user, errorUser] = await getUserGService({ email });
  if (user) {
    return res.status(409).json({ error: "El usuario ya está registrado" }); // 409: Conflict
  }
  const codigo = generarCodigo();
  try {
    await enviarCodigo(email, codigo);
    guardarCodigo(email, codigo); // lo guarda con tiempo
    res.json({ message: "Código enviado" });
  } catch (error) {
    console.error("Error al enviar el código:", error);
    res.status(500).json({ error: "No se pudo enviar el correo" });
  }
}

export async function sendCoder(req, res) {
  const { email } = req.body;

  try {
    const [user, errorUser] = await getUserGService({ email });
    if (errorUser) {
      return res.status(404).json({ error: errorUser }); // Usuario no encontrado
    }

    const codigo = generarCodigo();
    await enviarCodigoR(email, codigo);
    await guardarCodigo(email, codigo);

    return res.json({ message: "Código enviado" });
  } catch (error) {
    console.error("Error al enviar el código:", error);
    return res.status(500).json({ error: "No se pudo enviar el correo" });
  }
}

export function verifyCode(req, res) {
  const { email, code } = req.body;
  const codigoGuardado = obtenerCodigo(email);

  if (codigoGuardado === code) {
    eliminarCodigo(email);
    res.json({ message: "Código verificado correctamente" });
  } else {
    res.status(400).json({ error: "Código incorrecto o expirado" });
  }
}

function generarCodigo() {
  return Math.floor(100000 + Math.random() * 900000).toString(); // 6 dígitos
}
