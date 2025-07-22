"use strict";
import { AppDataSource } from "../config/configDb.js";
import SolicitudAmistad from "../entity/solicitudAmistad.entity.js";
import Notificacion from "../entity/notificacion.entity.js";

export async function obtenerNotificacionesService(rutUsuario) {
  try {
    // Obtener notificaciones generales
    const notificacionRepository = AppDataSource.getRepository(Notificacion);
    const notificacionesGenerales = await notificacionRepository.find({
      where: {
        rutReceptor: rutUsuario,
        leida: false
      },
      relations: ["emisor"], // Eliminamos "viaje" ya que está en MongoDB
      order: {
        fechaCreacion: "DESC"
      }
    });

    // Obtener solicitudes de amistad pendientes (para mantener compatibilidad)
    const solicitudRepository = AppDataSource.getRepository(SolicitudAmistad);
    const solicitudesPendientes = await solicitudRepository.find({
      where: {
        rutReceptor: rutUsuario,
        estado: "pendiente"
      },
      relations: ["emisor"],
      order: {
        fechaEnvio: "DESC"
      }
    });

    // Formatear notificaciones generales
    const notificaciones = notificacionesGenerales.map(notif => ({
      _id: notif.id.toString(), // Convertir ID a string
      titulo: notif.titulo,
      mensaje: notif.mensaje,
      tipo: notif.tipo,
      fechaCreacion: notif.fechaCreacion.toISOString(), // Convertir a string ISO
      leida: notif.leida,
      datos: {
        ...notif.datos,
        viajeId: notif.viajeId,
        solicitanteId: notif.rutEmisor,
        solicitanteNombre: notif.emisor?.nombreCompleto,
        // Los datos de origen/destino vendrán desde notif.datos
        origen: notif.datos?.origen,
        destino: notif.datos?.destino
      }
    }));

    // Formatear solicitudes de amistad como notificaciones (para compatibilidad)
    const solicitudesComoNotificaciones = solicitudesPendientes.map(solicitud => ({
      _id: `amistad_${solicitud.id}`,
      titulo: "Nueva solicitud de amistad",
      mensaje: `${solicitud.emisor?.nombreCompleto || 'Usuario'} te ha enviado una solicitud de amistad`,
      tipo: "solicitud_amistad",
      fechaCreacion: solicitud.fechaEnvio.toISOString(), // Convertir a string ISO
      leida: false,
      datos: {
        idSolicitud: solicitud.id,
        rutEmisor: solicitud.rutEmisor,
        nombreEmisor: solicitud.emisor?.nombreCompleto,
        mensaje: solicitud.mensaje
      }
    }));

    // Combinar y ordenar todas las notificaciones
    const todasLasNotificaciones = [...notificaciones, ...solicitudesComoNotificaciones]
      .sort((a, b) => new Date(b.fechaCreacion) - new Date(a.fechaCreacion));

    console.log(`📧 Notificaciones encontradas para ${rutUsuario}:`, todasLasNotificaciones.length);
    
    return [todasLasNotificaciones, null];
  } catch (error) {
    console.error("Error en obtenerNotificacionesService:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function contarNotificacionesPendientesService(rutUsuario) {
  try {
    // Contar notificaciones generales no leídas
    const notificacionRepository = AppDataSource.getRepository(Notificacion);
    const countNotificaciones = await notificacionRepository.count({
      where: {
        rutReceptor: rutUsuario,
        leida: false
      }
    });

    // Contar solicitudes de amistad pendientes
    const solicitudRepository = AppDataSource.getRepository(SolicitudAmistad);
    const countSolicitudes = await solicitudRepository.count({
      where: {
        rutReceptor: rutUsuario,
        estado: "pendiente"
      }
    });

    const totalCount = countNotificaciones + countSolicitudes;
    
    console.log(`📊 Conteo notificaciones para ${rutUsuario}: BD=${countNotificaciones}, Amistad=${countSolicitudes}, Total=${totalCount}`);
    
    return [totalCount, null];
  } catch (error) {
    console.error("Error en contarNotificacionesPendientesService:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function crearNotificacionService(datos) {
  try {
    const notificacionRepository = AppDataSource.getRepository(Notificacion);
    
    const nuevaNotificacion = notificacionRepository.create({
      tipo: datos.tipo,
      titulo: datos.titulo,
      mensaje: datos.mensaje,
      rutReceptor: datos.rutReceptor,
      rutEmisor: datos.rutEmisor,
      viajeId: datos.viajeId,
      datos: datos.datos || {}
    });

    const notificacionGuardada = await notificacionRepository.save(nuevaNotificacion);
    return [notificacionGuardada, null];
  } catch (error) {
    console.error("Error en crearNotificacionService:", error);
    return [null, "Error al crear la notificación"];
  }
}

export async function marcarComoLeidaService(notificacionId, rutUsuario) {
  try {
    const notificacionRepository = AppDataSource.getRepository(Notificacion);
    
    const notificacion = await notificacionRepository.findOne({
      where: {
        id: notificacionId,
        rutReceptor: rutUsuario
      }
    });

    if (!notificacion) {
      return [null, "Notificación no encontrada"];
    }

    notificacion.leida = true;
    await notificacionRepository.save(notificacion);
    
    return [notificacion, null];
  } catch (error) {
    console.error("Error en marcarComoLeidaService:", error);
    return [null, "Error al marcar como leída"];
  }
}

export async function responderSolicitudViajeService(notificacionId, aceptar, rutUsuario) {
  try {
    const notificacionRepository = AppDataSource.getRepository(Notificacion);
    
    const notificacion = await notificacionRepository.findOne({
      where: {
        id: notificacionId,
        rutReceptor: rutUsuario,
        tipo: "solicitud_viaje"
      },
      relations: ["emisor"]
    });

    if (!notificacion) {
      return [null, "Solicitud de viaje no encontrada"];
    }

    console.log(`🔍 Procesando respuesta a solicitud de viaje. Aceptar: ${aceptar}`);
    console.log(`📄 Datos de la notificación:`, JSON.stringify({
      id: notificacion.id,
      rutEmisor: notificacion.rutEmisor,
      rutReceptor: notificacion.rutReceptor,
      viajeId: notificacion.viajeId,
      datos: notificacion.datos
    }, null, 2));

    // Marcar la notificación como leída
    notificacion.leida = true;
    await notificacionRepository.save(notificacion);

    if (aceptar) {
      // Importar el modelo de viaje de MongoDB
      const { default: Viaje } = await import('../entity/viaje.entity.js');
      
      // Buscar el viaje en MongoDB
      const viaje = await Viaje.findById(notificacion.viajeId);
      if (!viaje) {
        return [null, "Viaje no encontrado"];
      }

      // Verificar que hay espacio disponible
      if (viaje.pasajeros.length >= viaje.maxPasajeros) {
        return [null, "El viaje está completo"];
      }

      // Verificar que el pasajero no está ya en el viaje
      const yaEsPasajero = viaje.pasajeros.some(p => p.usuario_rut === notificacion.rutEmisor);
      if (yaEsPasajero) {
        return [null, "El pasajero ya está registrado en este viaje"];
      }

      // **PROCESAR PAGO SI HAY INFORMACIÓN DE PAGO**
      let resultadoPago = null;
      if (notificacion.datos && notificacion.datos.pago) {
        console.log(`💳 ¡INFORMACIÓN DE PAGO ENCONTRADA EN NOTIFICACIÓN! Procesando pago para pasajero ${notificacion.rutEmisor}: ${JSON.stringify(notificacion.datos.pago)}`);
        
        try {
          // Importar la función de procesamiento de pago
          const { procesarPagoViajeService } = await import('./pago.service.js');
          
          resultadoPago = await procesarPagoViajeService({
            pasajeroRut: notificacion.rutEmisor,
            conductorRut: rutUsuario,
            viajeId: notificacion.viajeId,
            monto: notificacion.datos.pago.monto,
            descripcion: "Pago por viaje compartido"
          });
          
          console.log(`✅ ¡PAGO PROCESADO EXITOSAMENTE EN NOTIFICACIÓN!: ${JSON.stringify(resultadoPago)}`);
        } catch (pagoError) {
          console.error(`❌ ERROR AL PROCESAR PAGO EN NOTIFICACIÓN:`, pagoError);
          return [null, `Error al procesar el pago: ${pagoError.message}`];
        }
      } else {
        console.log(`⚠️ NO SE ENCONTRÓ INFORMACIÓN DE PAGO en la notificación`);
      }

      // Agregar al pasajero al viaje
      viaje.pasajeros.push({
        usuario_rut: notificacion.rutEmisor,
        estado: 'confirmado',
        fecha_union: new Date()
      });

      viaje.fecha_actualizacion = new Date();
      await viaje.save();

      console.log(`✅ Pasajero ${notificacion.rutEmisor} agregado al viaje ${notificacion.viajeId}`);

      // Intentar agregar al pasajero al chat grupal
      console.log(`🔄 Intentando agregar pasajero ${notificacion.rutEmisor} al chat grupal del viaje ${notificacion.viajeId}`);
      try {
        const { agregarParticipante } = await import('../services/chatGrupal.service.js');
        await agregarParticipante(notificacion.viajeId, notificacion.rutEmisor);
        console.log(`✅ Pasajero ${notificacion.rutEmisor} agregado EXITOSAMENTE al chat grupal del viaje ${notificacion.viajeId}`);
      } catch (chatError) {
        console.error(`❌ ERROR al agregar pasajero ${notificacion.rutEmisor} al chat grupal del viaje ${notificacion.viajeId}:`, chatError.message);
        
        // Si el chat grupal no existe, intentamos crearlo
        if (chatError.message.includes("Chat grupal no encontrado")) {
          console.log(`� Intentando crear chat grupal para el viaje ${notificacion.viajeId}`);
          try {
            const { crearChatGrupal } = await import('../services/chatGrupal.service.js');
            await crearChatGrupal(notificacion.viajeId, rutUsuario);
            console.log(`✅ Chat grupal creado para viaje ${notificacion.viajeId}`);
            
            // Intentar agregar al participante nuevamente
            const { agregarParticipante } = await import('../services/chatGrupal.service.js');
            await agregarParticipante(notificacion.viajeId, notificacion.rutEmisor);
            console.log(`✅ Pasajero ${notificacion.rutEmisor} agregado al chat grupal después de crearlo`);
          } catch (crearError) {
            console.error(`❌ ERROR CRÍTICO: No se pudo crear ni agregar al chat grupal:`, crearError.message);
            throw new Error(`Error crítico en chat grupal: ${crearError.message}`);
          }
        } else {
          throw chatError;
        }
      }
      
      const response = { 
        mensaje: "Solicitud de viaje aceptada y pasajero agregado", 
        aceptado: true,
        viajeId: notificacion.viajeId,
        pasajeroRut: notificacion.rutEmisor
      };

      // Agregar información de pago si se procesó
      if (resultadoPago) {
        response.pago = resultadoPago;
      }
      
      return [response, null];
    } else {
      console.log(`❌ Solicitud de viaje rechazada para ${notificacion.rutEmisor} en viaje ${notificacion.viajeId}`);
      return [{ mensaje: "Solicitud de viaje rechazada", aceptado: false }, null];
    }
  } catch (error) {
    console.error("Error en responderSolicitudViajeService:", error);
    return [null, "Error al procesar la respuesta"];
  }
}

/**
 * Crear una solicitud de viaje (notificación)
 */
export async function crearSolicitudViaje({ conductorRut, pasajeroRut, viajeId, mensaje, informacionPago }) {
  try {
    const notificacionRepository = AppDataSource.getRepository(Notificacion);
    
    // Verificar si ya existe una solicitud pendiente para este viaje
    const solicitudExistente = await notificacionRepository.findOne({
      where: {
        rutEmisor: pasajeroRut,
        rutReceptor: conductorRut,
        tipo: 'solicitud_viaje',
        viajeId: viajeId,
        leida: false
      }
    });

    if (solicitudExistente) {
      throw new Error("Ya tienes una solicitud pendiente para este viaje");
    }

    // Importar Viaje para obtener detalles
    const { default: Viaje } = await import('../entity/viaje.entity.js');
    const viaje = await Viaje.findById(viajeId);
    
    if (!viaje) {
      throw new Error("Viaje no encontrado");
    }

    // Preparar datos de la notificación
    const datosNotificacion = {
      origen: viaje.origen.nombre,
      destino: viaje.destino.nombre,
      fecha: viaje.fecha_ida,
      hora: viaje.hora_ida
    };

    // Agregar información de pago si está presente
    if (informacionPago) {
      datosNotificacion.pago = informacionPago;
      console.log(`💳 Solicitud incluye información de pago: ${informacionPago.metodo} por $${informacionPago.monto}`);
    }

    // Crear nueva notificación
    const nuevaNotificacion = notificacionRepository.create({
      rutEmisor: pasajeroRut,
      rutReceptor: conductorRut,
      tipo: 'solicitud_viaje',
      titulo: informacionPago ? 'Nueva solicitud de viaje con pago' : 'Nueva solicitud de viaje',
      mensaje: mensaje || `Solicitud para unirse al viaje de ${viaje.origen.nombre} a ${viaje.destino.nombre}`,
      viajeId: viajeId,
      datos: datosNotificacion,
      fechaCreacion: new Date(),
      leida: false
    });

    await notificacionRepository.save(nuevaNotificacion);
    
    console.log(`✅ Solicitud de viaje creada: ${pasajeroRut} → ${conductorRut} para viaje ${viajeId}`);
    if (informacionPago) {
      console.log(`💰 Con información de pago: ${informacionPago.metodo} - $${informacionPago.monto}`);
    }
    
    return nuevaNotificacion;
  } catch (error) {
    console.error("Error en crearSolicitudViaje:", error);
    throw error;
  }
}
