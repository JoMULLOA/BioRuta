// src/services/chat.service.js
import Mensaje from "../entity/mensaje.entity.js";
import User from "../entity/user.entity.js"; // Importamos la entidad User para buscar los usuarios
import { AppDataSource } from "../config/configDb.js";

const mensajeRepository = AppDataSource.getRepository(Mensaje);
const userRepository = AppDataSource.getRepository(User);

// Función para enviar un mensaje
export async function enviarMensaje(rutEmisor, rutReceptor, contenido) {
  try {
    // Buscar los usuarios por su rut
    const emisor = await userRepository.findOne({ where: { rut: rutEmisor } });
    const receptor = await userRepository.findOne({ where: { rut: rutReceptor } });

    // Verificar si los usuarios existen
    if (!emisor) {
      throw new Error("El emisor no existe");
    }
    if (!receptor) {
      throw new Error("El receptor no existe");
    }

    // Crear un nuevo mensaje y asociarlo a los usuarios
    const nuevoMensaje = mensajeRepository.create({
      contenido,
      emisor,      // Relación con el usuario emisor
      receptor,    // Relación con el usuario receptor
    });

    // Guardar el mensaje en la base de datos
    return await mensajeRepository.save(nuevoMensaje);
  } catch (error) {
    console.error("Error al enviar el mensaje:", error);
    throw new Error("Error al enviar el mensaje");
  }
}

// Función para obtener la conversación entre dos usuarios
export async function obtenerConversacion(rutUsuario1, rutUsuario2) {
  try {
    // Buscar los mensajes entre los dos usuarios, donde uno es emisor y el otro receptor
    const mensajes = await mensajeRepository.find({
      where: [
        { emisor: { rut: rutUsuario1 }, receptor: { rut: rutUsuario2 }, eliminado: false },
        { emisor: { rut: rutUsuario2 }, receptor: { rut: rutUsuario1 }, eliminado: false },
      ],
      order: { fecha: "ASC" }, // Ordenar los mensajes por fecha ascendente
      relations: ["emisor", "receptor"], // Cargar las relaciones de emisor y receptor
    });

    return mensajes;
  } catch (error) {
    console.error("Error al obtener la conversación:", error);
    throw new Error("Error al obtener la conversación");
  }
}

// Función para editar un mensaje
export async function editarMensaje(idMensaje, rutEmisor, nuevoContenido) {
  try {
    const mensaje = await mensajeRepository.findOne({
      where: { id: idMensaje },
      relations: ["emisor"],
    });

    if (!mensaje) {
      throw new Error("Mensaje no encontrado");
    }

    // Verificar que el emisor sea el que está editando el mensaje
    if (mensaje.emisor.rut !== rutEmisor) {
      throw new Error("No tienes permiso para editar este mensaje");
    }

    // Actualizar el contenido y marcar el mensaje como editado
    mensaje.contenido = nuevoContenido;
    mensaje.editado = true;  // Marcamos el mensaje como editado
    return await mensajeRepository.save(mensaje);
  } catch (error) {
    console.error("Error al editar el mensaje:", error);
    throw new Error("Error al editar el mensaje");
  }
}

// Función para eliminar (soft delete) un mensaje
export async function eliminarMensaje(idMensaje, rutEmisor) {
  try {
    const mensaje = await mensajeRepository.findOne({
      where: { id: idMensaje },
      relations: ["emisor"],
    });

    if (!mensaje) {
      throw new Error("Mensaje no encontrado");
    }

    if (mensaje.emisor.rut !== rutEmisor) {
      throw new Error("No tienes permiso para eliminar este mensaje");
    }

    // Marcamos el mensaje como eliminado (soft delete)
    mensaje.eliminado = true;
    await mensajeRepository.save(mensaje);
    return { mensaje: "Mensaje eliminado exitosamente" };
  } catch (error) {
    console.error("Error al eliminar el mensaje:", error);
    throw new Error("Error al eliminar el mensaje");
  }
}
