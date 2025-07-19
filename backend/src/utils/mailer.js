import nodemailer from "nodemailer";

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASS,
  },
});

export async function enviarCodigo(email, codigo) {
  const opciones = {
    from: `"BioRuta App" <${process.env.GMAIL_USER}>`,
    to: email,
    subject: "Código de verificación",
    html: `
      <p>Bienvenido a <b>BioRuta</b>,</p>
      <p>Tu código de verificación para registrarte es: <b>${codigo}</b></p>
    `,
  };

  return transporter.sendMail(opciones);
}

export async function enviarCodigoR(email, codigo) {
  const opciones = {
    from: `"BioRuta App" <${process.env.GMAIL_USER}>`,
    to: email,
    subject: "Código de recuperación",
    html: `
      <p>Te saludamos desde <b>BioRuta</b>,</p>
      <p>Tu código de recuperación es: <b>${codigo}</b></p>
    `,
  };

  return transporter.sendMail(opciones);
}