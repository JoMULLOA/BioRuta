"use strict";
import { AppDataSource } from "../config/configDb.js";
import SolicitudAmistad from "../entity/solicitudAmistad.entity.js";
import Amistad from "../entity/amistad.entity.js";
import User from "../entity/user.entity.js";

export async function enviarSolicitudAmistadService(rutEmisor, rutReceptor, mensaje = null) {
  try {
    console.log(`🚀 DEBUG - Iniciando envío de solicitud: ${rutEmisor} -> ${rutReceptor}`);
    
    const solicitudRepository = AppDataSource.getRepository(SolicitudAmistad);
    const amistadRepository = AppDataSource.getRepository(Amistad);
    const userRepository = AppDataSource.getRepository(User);

    // Verificar que ambos usuarios existen
    const emisor = await userRepository.findOne({ where: { rut: rutEmisor } });
    const receptor = await userRepository.findOne({ where: { rut: rutReceptor } });

    console.log(`🔍 DEBUG - Emisor encontrado:`, emisor ? 'SÍ' : 'NO');
    console.log(`🔍 DEBUG - Receptor encontrado:`, receptor ? 'SÍ' : 'NO');

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
        { rutUsuario1: rutEmisor, rutUsuario2: rutReceptor, bloqueado: false },
        { rutUsuario1: rutReceptor, rutUsuario2: rutEmisor, bloqueado: false }
      ]
    });

    console.log(`🤝 DEBUG - Amistad existente:`, amistadExistente ? 'SÍ' : 'NO');

    if (amistadExistente) {
      return [null, "Ya son amigos"];
    }

    // Verificar si ya existe una solicitud en cualquier estado
    console.log(`🔍 DEBUG - Consultando solicitudes existentes con queries:`);
    console.log(`   Query 1: rutEmisor=${rutEmisor}, rutReceptor=${rutReceptor}`);
    console.log(`   Query 2: rutEmisor=${rutReceptor}, rutReceptor=${rutEmisor}`);
    
    const solicitudExistente = await solicitudRepository.findOne({
      where: [
        { rutEmisor, rutReceptor },
        { rutEmisor: rutReceptor, rutReceptor: rutEmisor }
      ]
    });

    console.log(`🔍 DEBUG - Solicitud existente encontrada:`, solicitudExistente ? `SÍ (ID: ${solicitudExistente.id}, Estado: ${solicitudExistente.estado})` : 'NO');

    if (solicitudExistente) {
      switch (solicitudExistente.estado) {
        case "pendiente":
          // Si la solicitud existente es del mismo emisor
          if (solicitudExistente.rutEmisor === rutEmisor) {
            return [null, "Ya enviaste una solicitud a este usuario"];
          } else {
            return [null, "Este usuario ya te envió una solicitud. Revisa tus notificaciones"];
          }
        
        case "aceptada":
          // Si hay una solicitud aceptada pero NO hay amistad activa, 
          // significa que la amistad fue eliminada - permitir nueva solicitud
          const verificarAmistad = await amistadRepository.findOne({
            where: [
              { rutUsuario1: rutEmisor, rutUsuario2: rutReceptor, bloqueado: false },
              { rutUsuario1: rutReceptor, rutUsuario2: rutEmisor, bloqueado: false }
            ]
          });
          
          if (verificarAmistad) {
            return [null, "Ya son amigos"];
          } else {
            // Amistad eliminada - limpiar solicitud aceptada y permitir nueva
            console.log(`🔄 Amistad fue eliminada - limpiando solicitud aceptada y permitiendo nueva`);
            await solicitudRepository.remove(solicitudExistente);
          }
          break;
        
        case "rechazada":
          // Solo permitir nueva solicitud si han pasado al menos 24 horas
          const tiempoEspera = 24 * 60 * 60 * 1000; // 24 horas en ms
          const tiempoTranscurrido = new Date() - new Date(solicitudExistente.fechaRespuesta);
          
          if (tiempoTranscurrido < tiempoEspera) {
            return [null, "Debes esperar 24 horas antes de enviar otra solicitud"];
          }
          
          // Reutilizar la solicitud existente actualizándola
          console.log(`🔄 Reutilizando solicitud rechazada - actualizando a pendiente`);
          solicitudExistente.rutEmisor = rutEmisor;
          solicitudExistente.rutReceptor = rutReceptor;
          solicitudExistente.mensaje = mensaje;
          solicitudExistente.estado = "pendiente";
          solicitudExistente.fechaEnvio = new Date();
          solicitudExistente.fechaRespuesta = null;
          
          const solicitudActualizada = await solicitudRepository.save(solicitudExistente);
          console.log(`✅ DEBUG - Solicitud actualizada con ID: ${solicitudActualizada.id}`);
          return [solicitudActualizada, null];
      }
    }

    // Crear nueva solicitud
    const nuevaSolicitud = solicitudRepository.create({
      rutEmisor,
      rutReceptor,
      mensaje,
      estado: "pendiente"
    });

    console.log(`✅ DEBUG - Creando nueva solicitud: ${rutEmisor} -> ${rutReceptor}`);
    const solicitudGuardada = await solicitudRepository.save(nuevaSolicitud);
    console.log(`✅ DEBUG - Solicitud guardada con ID: ${solicitudGuardada.id}`);

    return [solicitudGuardada, null];
  } catch (error) {
    console.error("Error en enviarSolicitudAmistadService:", error);
    
    // Manejar error específico de duplicado
    if (error.code === '23505' && error.constraint === 'UNIQUE_SOLICITUD') {
      return [null, "Ya existe una solicitud entre estos usuarios"];
    }
    
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
    const solicitudRepository = AppDataSource.getRepository(SolicitudAmistad);

    console.log(`🗑️ DEBUG - Eliminando amistad entre ${rutUsuario} y ${rutAmigo}`);

    // Buscar la amistad
    const amistad = await amistadRepository.findOne({
      where: [
        { rutUsuario1: rutUsuario, rutUsuario2: rutAmigo },
        { rutUsuario1: rutAmigo, rutUsuario2: rutUsuario }
      ]
    });

    if (!amistad) {
      return [null, "Amistad no encontrada"];
    }

    // Eliminar la amistad
    await amistadRepository.remove(amistad);
    console.log(`✅ DEBUG - Amistad eliminada de tabla amistades`);

    // IMPORTANTE: Limpiar la solicitud aceptada para permitir nuevas solicitudes
    const solicitudAceptada = await solicitudRepository.findOne({
      where: [
        { rutEmisor: rutUsuario, rutReceptor: rutAmigo, estado: "aceptada" },
        { rutEmisor: rutAmigo, rutReceptor: rutUsuario, estado: "aceptada" }
      ]
    });

    if (solicitudAceptada) {
      console.log(`🧹 DEBUG - Limpiando solicitud aceptada (ID: ${solicitudAceptada.id}) para permitir nuevas solicitudes`);
      await solicitudRepository.remove(solicitudAceptada);
      console.log(`✅ DEBUG - Solicitud aceptada limpiada`);
    } else {
      console.log(`⚠️ DEBUG - No se encontró solicitud aceptada para limpiar`);
    }

    return [{ mensaje: "Amistad eliminada correctamente" }, null];
  } catch (error) {
    console.error("Error en eliminarAmistadService:", error);
    return [null, "Error interno del servidor"];
  }
}
