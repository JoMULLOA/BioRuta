import { enviarCodigo, enviarCodigoR } from "../utils/mailer.js";
import { guardarCodigo, obtenerCodigo, eliminarCodigo } from "../utils/veritemp.js"; // funciones para guardar, obtener y eliminar el código
import { getUserGService } from "../services/user.service.js";

export async function sendCode(req, res) {
  const { email } = req.body;
  const codigo = generarCodigo(); // función abajo

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
