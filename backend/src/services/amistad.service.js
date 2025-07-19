"use strict";
import { AppDataSource } from "../config/configDb.js";
import SolicitudAmistad from "../entity/solicitudAmistad.entity.js";
import Amistad from "../entity/amistad.entity.js";
import User from "../entity/user.entity.js";

export async function enviarSolicitudAmistadService(rutEmisor, rutReceptor, mensaje = null) {
  try {
    const solicitudRepository = AppDataSource.getRepository(SolicitudAmistad);
    const amistadRepository = AppDataSource.getRepository(Amistad);
    const userRepository = AppDataSource.getRepository(User);

    // Verificar que ambos usuarios existen
    const emisor = await userRepository.findOne({ where: { rut: rutEmisor } });
    const receptor = await userRepository.findOne({ where: { rut: rutReceptor } });

    if (!emisor) {
      return [null, "Usuario emisor no encontrado"];
    }

    if (!receptor) {
      return [null, "Usuario receptor no encontrado"];
    }

    // No permitir enviarse solicitud a sí mismo
    if (rutEmisor === rutReceptor) {
      return [null, "No puedes enviarte una solicitud a ti mismo"];
    }

    // Verificar si ya son amigos
    const amistadExistente = await amistadRepository.findOne({
      where: [
        { rutUsuario1: rutEmisor, rutUsuario2: rutReceptor },
        { rutUsuario1: rutReceptor, rutUsuario2: rutEmisor }
      ]
    });

    if (amistadExistente) {
      return [null, "Ya son amigos"];
    }

    // Verificar si ya existe una solicitud pendiente
    const solicitudExistente = await solicitudRepository.findOne({
      where: [
        { rutEmisor, rutReceptor, estado: "pendiente" },
        { rutEmisor: rutReceptor, rutReceptor: rutEmisor, estado: "pendiente" }
      ]
    });

    if (solicitudExistente) {
      return [null, "Ya existe una solicitud pendiente entre estos usuarios"];
    }

    // Crear nueva solicitud
    const nuevaSolicitud = solicitudRepository.create({
      rutEmisor,
      rutReceptor,
      mensaje,
      estado: "pendiente"
    });

    const solicitudGuardada = await solicitudRepository.save(nuevaSolicitud);

    return [solicitudGuardada, null];
  } catch (error) {
    console.error("Error en enviarSolicitudAmistadService:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function responderSolicitudAmistadService(idSolicitud, rutReceptor, respuesta) {
  try {
    const solicitudRepository = AppDataSource.getRepository(SolicitudAmistad);
    const amistadRepository = AppDataSource.getRepository(Amistad);

    // Buscar la solicitud
    const solicitud = await solicitudRepository.findOne({
      where: { 
        id: idSolicitud, 
        rutReceptor, 
        estado: "pendiente" 
      }
    });

    if (!solicitud) {
      return [null, "Solicitud no encontrada o no tienes permisos para responderla"];
    }

    // Actualizar estado de la solicitud
    solicitud.estado = respuesta;
    solicitud.fechaRespuesta = new Date();
    
    await solicitudRepository.save(solicitud);

    // Si fue aceptada, crear la amistad
    if (respuesta === "aceptada") {
      // Asegurar orden consistente en la amistad
      const rutMenor = solicitud.rutEmisor < solicitud.rutReceptor ? solicitud.rutEmisor : solicitud.rutReceptor;
      const rutMayor = solicitud.rutEmisor > solicitud.rutReceptor ? solicitud.rutEmisor : solicitud.rutReceptor;

      const nuevaAmistad = amistadRepository.create({
        rutUsuario1: rutMenor,
        rutUsuario2: rutMayor
      });

      const amistadGuardada = await amistadRepository.save(nuevaAmistad);
      return [{ solicitud, amistad: amistadGuardada }, null];
    }

    return [{ solicitud }, null];
  } catch (error) {
    console.error("Error en responderSolicitudAmistadService:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function obtenerSolicitudesPendientesService(rutUsuario) {
  try {
    const solicitudRepository = AppDataSource.getRepository(SolicitudAmistad);

    const solicitudesPendientes = await solicitudRepository.find({
      where: {
        rutReceptor: rutUsuario,
        estado: "pendiente"
      },
      order: {
        fechaEnvio: "DESC"
      }
    });

    return [solicitudesPendientes, null];
  } catch (error) {
    console.error("Error en obtenerSolicitudesPendientesService:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function obtenerAmigosService(rutUsuario) {
  try {
    const amistadRepository = AppDataSource.getRepository(Amistad);

    const amistades = await amistadRepository.find({
      where: [
        { rutUsuario1: rutUsuario, bloqueado: false },
        { rutUsuario2: rutUsuario, bloqueado: false }
      ],
      order: {
        fechaAmistad: "DESC"
      }
    });

    // Formatear la respuesta para incluir solo los datos del amigo
    const amigos = amistades.map(amistad => {
      const esUsuario1 = amistad.rutUsuario1 === rutUsuario;
      return {
        id: amistad.id,
        amigo: esUsuario1 ? amistad.usuario2 : amistad.usuario1,
        fechaAmistad: amistad.fechaAmistad
      };
    });

    return [amigos, null];
  } catch (error) {
    console.error("Error en obtenerAmigosService:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function eliminarAmistadService(rutUsuario, rutAmigo) {
  try {
    const amistadRepository = AppDataSource.getRepository(Amistad);

    const amistad = await amistadRepository.findOne({
      where: [
        { rutUsuario1: rutUsuario, rutUsuario2: rutAmigo },
        { rutUsuario1: rutAmigo, rutUsuario2: rutUsuario }
      ]
    });

    if (!amistad) {
      return [null, "Amistad no encontrada"];
    }

    await amistadRepository.remove(amistad);
    return [{ mensaje: "Amistad eliminada correctamente" }, null];
  } catch (error) {
    console.error("Error en eliminarAmistadService:", error);
    return [null, "Error interno del servidor"];
  }
}
