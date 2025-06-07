// src/services/chat.service.js
import Mensaje from "../entity/mensaje.entity.js";
import { AppDataSource } from "../config/configDb.js";

const mensajeRepository = AppDataSource.getRepository(Mensaje);

export async function enviarMensaje(rutEmisor, rutReceptor, contenido) {
  const nuevoMensaje = mensajeRepository.create({
    contenido,
    emisor: { rut: rutEmisor },
    receptor: { rut: rutReceptor },
  });

  return await mensajeRepository.save(nuevoMensaje);
}

export async function obtenerConversacion(rutUsuario1, rutUsuario2) {
  return await mensajeRepository.find({
    where: [
      { emisor: { rut: rutUsuario1 }, receptor: { rut: rutUsuario2 } },
      { emisor: { rut: rutUsuario2 }, receptor: { rut: rutUsuario1 } },
    ],
    order: { fecha: "ASC" },
  });
}
