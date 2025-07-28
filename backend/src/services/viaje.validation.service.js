"use strict";
import Viaje from "../entity/viaje.entity.js";
import { AppDataSource } from "../config/configDb.js";
import { crearNotificacionService, obtenerNotificacionesService } from "./notificacion.service.js";
import { convertirFechaChile, obtenerFechaActualChile } from "../utils/dateChile.js";

const userRepository = AppDataSource.getRepository("User");

/**
 * Validar si un viaje puede cambiar automáticamente de estado
 * @param {String} viajeId - ID del viaje
 * @returns {Object} - Resultado de la validación
 */
export async function validarCambioEstadoAutomatico(viajeId) {
  try {
    const viaje = await Viaje.findById(viajeId);
    
    if (!viaje) {
      return {
        valido: false,
        razon: 'Viaje no encontrado'
      };
    }

    // Validación 1: Si es hora de iniciar y no hay pasajeros confirmados, cancelar
    if (viaje.estado === 'activo') {
      // Hora actual Chile
      const now = obtenerFechaActualChile();
      const fechaIda = convertirFechaChile(viaje.fecha_ida);
      
      // Si ya pasó la hora de salida
      if (now >= fechaIda) {
        const pasajerosConfirmados = viaje.pasajeros.filter(p => p.estado === 'confirmado');
        
        if (pasajerosConfirmados.length === 0) {
          return {
            valido: true,
            nuevoEstado: 'cancelado',
            razon: 'Viaje cancelado automáticamente: sin pasajeros confirmados a la hora de salida'
          };
        }
        
        // Si hay pasajeros confirmados, cambiar a en_curso
        return {
          valido: true,
          nuevoEstado: 'en_curso',
          razon: 'Viaje iniciado automáticamente a la hora programada'
        };
      }
    }

    return {
      valido: false,
      razon: 'No requiere cambio de estado automático'
    };

  } catch (error) {
    console.error('Error validando cambio de estado automático:', error);
    return {
      valido: false,
      razon: 'Error interno en la validación'
    };
  }
}

/**
 * Validar si un conductor puede iniciar un viaje manualmente
 * @param {String} viajeId - ID del viaje
 * @param {String} conductorRut - RUT del conductor
 * @returns {Object} - Resultado de la validación
 */
export async function validarInicioViaje(viajeId, conductorRut) {
  try {
    const viaje = await Viaje.findById(viajeId);
    
    if (!viaje) {
      return {
        valido: false,
        razon: 'Viaje no encontrado'
      };
    }

    // Verificar que es el conductor del viaje
    if (viaje.usuario_rut !== conductorRut) {
      return {
        valido: false,
        razon: 'Solo el conductor puede iniciar el viaje'
      };
    }

    // Verificar que el viaje está activo
    if (viaje.estado !== 'activo') {
      return {
        valido: false,
        razon: `No se puede iniciar un viaje en estado: ${viaje.estado}`
      };
    }

    // Validación 2: Verificar que no hay notificaciones pendientes
    const [notificacionesPendientes, error] = await obtenerNotificacionesService(conductorRut);
    
    if (error) {
      console.error('Error obteniendo notificaciones:', error);
      // Continuar con la validación aunque falle obtener notificaciones
    } else if (notificacionesPendientes && notificacionesPendientes.length > 0) {
      // Filtrar solo notificaciones de solicitudes de viaje para este viaje específico
      const solicitudesPendientes = notificacionesPendientes.filter(n => 
        n.tipo === 'ride_request' && 
        n.leida === false &&
        n.viajeId === viajeId
      );
      
      if (solicitudesPendientes.length > 0) {
        return {
          valido: false,
          razon: `Tienes ${solicitudesPendientes.length} solicitud(es) de pasajeros pendientes para este viaje. Debes responderlas antes de iniciarlo.`
        };
      }
    }

    // Validación 3: Verificar que hay al menos un pasajero confirmado
    const pasajerosConfirmados = viaje.pasajeros.filter(p => p.estado === 'confirmado');
    
    if (pasajerosConfirmados.length === 0) {
      return {
        valido: false,
        razon: 'No puedes iniciar un viaje sin pasajeros confirmados'
      };
    }

    return {
      valido: true,
      razon: 'El viaje puede iniciarse'
    };

  } catch (error) {
    console.error('Error validando inicio de viaje:', error);
    return {
      valido: false,
      razon: 'Error interno en la validación'
    };
  }
}

/**
 * Validar conflictos de horarios para un usuario
 * @param {String} usuarioRut - RUT del usuario
 * @param {Date} fechaHoraIda - Fecha y hora de ida del nuevo viaje
 * @param {Date} fechaHoraVuelta - Fecha y hora de vuelta (opcional)
 * @param {String} viajeExcluidoId - ID del viaje a excluir (para ediciones)
 * @returns {Object} - Resultado de la validación
 */
export async function validarConflictoHorarios(usuarioRut, fechaHoraIda, fechaHoraVuelta = null, viajeExcluidoId = null) {
  try {
    // Usar hora chilena para conflictos de horarios
    const fechaHoraIdaChile = convertirFechaChile(fechaHoraIda);
    const fechaHoraVueltaChile = fechaHoraVuelta ? convertirFechaChile(fechaHoraVuelta) : null;

    // Crear filtro base
    const filtroBase = {
      $or: [
        { usuario_rut: usuarioRut }, // Viajes como conductor
        { 
          'pasajeros.usuario_rut': usuarioRut,
          'pasajeros.estado': { $in: ['confirmado', 'pendiente'] }
        } // Viajes como pasajero
      ],
      estado: { $in: ['activo', 'en_curso'] }
    };

    // Excluir viaje específico si se proporciona (para ediciones)
    if (viajeExcluidoId) {
      filtroBase._id = { $ne: viajeExcluidoId };
    }

    // Buscar viajes existentes del usuario
    const viajesExistentes = await Viaje.find(filtroBase);

    // Definir margen de tiempo mínimo (6 horas = 360 minutos)
    const MARGEN_MINIMO_HORAS = 6;
    const MARGEN_MINIMO_MS = MARGEN_MINIMO_HORAS * 60 * 60 * 1000;

    for (const viajeExistente of viajesExistentes) {
      const fechaIdaExistente = convertirFechaChile(viajeExistente.fecha_ida);
      const fechaVueltaExistente = viajeExistente.fecha_vuelta ? convertirFechaChile(viajeExistente.fecha_vuelta) : null;

      // Verificar conflicto con ida del nuevo viaje
      const diferenciaIda = Math.abs(fechaHoraIdaChile.getTime() - fechaIdaExistente.getTime());
      
      if (diferenciaIda < MARGEN_MINIMO_MS) {
        return {
          valido: false,
          razon: `Conflicto de horarios: tienes otro viaje programado el ${fechaIdaExistente.toLocaleDateString('es-CL')} a las ${fechaIdaExistente.toLocaleTimeString('es-CL', { hour: '2-digit', minute: '2-digit' })}. Debe haber al menos ${MARGEN_MINIMO_HORAS} horas de diferencia entre viajes.`,
          viajeConflicto: viajeExistente._id
        };
      }

      // Si el viaje existente tiene vuelta, verificar también
      if (fechaVueltaExistente) {
        const diferenciaConVuelta = Math.abs(fechaHoraIdaChile.getTime() - fechaVueltaExistente.getTime());
        
        if (diferenciaConVuelta < MARGEN_MINIMO_MS) {
          return {
            valido: false,
            razon: `Conflicto de horarios: tienes otro viaje con vuelta programada el ${fechaVueltaExistente.toLocaleDateString('es-CL')} a las ${fechaVueltaExistente.toLocaleTimeString('es-CL', { hour: '2-digit', minute: '2-digit' })}. Debe haber al menos ${MARGEN_MINIMO_HORAS} horas de diferencia entre viajes.`,
            viajeConflicto: viajeExistente._id
          };
        }
      }

      // Si el nuevo viaje tiene vuelta, verificar conflictos con ella también
      if (fechaHoraVueltaChile) {
        const diferenciaVueltaNueva = Math.abs(fechaHoraVueltaChile.getTime() - fechaIdaExistente.getTime());
        
        if (diferenciaVueltaNueva < MARGEN_MINIMO_MS) {
          return {
            valido: false,
            razon: `Conflicto de horarios: la vuelta de tu viaje está muy cerca de otro viaje programado el ${fechaIdaExistente.toLocaleDateString('es-CL')}. Debe haber al menos ${MARGEN_MINIMO_HORAS} horas de diferencia.`,
            viajeConflicto: viajeExistente._id
          };
        }

        // Verificar vuelta nueva con vuelta existente
        if (fechaVueltaExistente) {
          const diferenciaVueltas = Math.abs(fechaHoraVueltaChile.getTime() - fechaVueltaExistente.getTime());
          
          if (diferenciaVueltas < MARGEN_MINIMO_MS) {
            return {
              valido: false,
              razon: `Conflicto de horarios: la vuelta de tu viaje está muy cerca de la vuelta de otro viaje. Debe haber al menos ${MARGEN_MINIMO_HORAS} horas de diferencia.`,
              viajeConflicto: viajeExistente._id
            };
          }
        }
      }
    }

    return {
      valido: true,
      razon: 'No hay conflictos de horarios'
    };

  } catch (error) {
    console.error('Error validando conflictos de horarios:', error);
    return {
      valido: false,
      razon: 'Error interno en la validación de horarios'
    };
  }
}

/**
 * Aplicar cambio de estado automático
 * @param {String} viajeId - ID del viaje
 * @param {String} nuevoEstado - Nuevo estado del viaje
 * @param {String} razon - Razón del cambio
 * @returns {Object} - Resultado de la operación
 */
export async function aplicarCambioEstadoAutomatico(viajeId, nuevoEstado, razon) {
  try {
    const viaje = await Viaje.findByIdAndUpdate(
      viajeId,
      { 
        estado: nuevoEstado,
        fecha_actualizacion: new Date()
      },
      { new: true }
    );

    if (!viaje) {
      return {
        exito: false,
        mensaje: 'Viaje no encontrado'
      };
    }

    // Log del cambio automático
    console.log(`🔄 Cambio automático de estado aplicado:
      - Viaje: ${viajeId}
      - Estado anterior: activo
      - Estado nuevo: ${nuevoEstado}
      - Razón: ${razon}
      - Fecha: ${new Date().toISOString()}`
    );

    // Si el viaje se canceló automáticamente, notificar a los pasajeros
    if (nuevoEstado === 'cancelado') {
      const pasajeros = viaje.pasajeros.filter(p => p.estado === 'pendiente' || p.estado === 'confirmado');
      
      for (const pasajero of pasajeros) {
        try {
          const [notificacion, errorNotif] = await crearNotificacionService({
            rutReceptor: pasajero.usuario_rut,
            rutEmisor: null, // Sistema automático
            tipo: 'trip_cancelled',
            titulo: 'Viaje cancelado automáticamente',
            mensaje: `El viaje programado fue cancelado automáticamente: ${razon}`,
            viajeId: viajeId,
            datos: {
              viaje_id: viajeId,
              razon_automatica: razon,
              cancelacion_automatica: true
            }
          });
          
          if (errorNotif) {
            console.error(`Error notificando cancelación a pasajero ${pasajero.usuario_rut}:`, errorNotif);
          }
        } catch (notifError) {
          console.error(`Error notificando cancelación a pasajero ${pasajero.usuario_rut}:`, notifError);
        }
      }
    }

    return {
      exito: true,
      mensaje: `Estado cambiado automáticamente a: ${nuevoEstado}`,
      viaje: viaje,
      razon: razon
    };

  } catch (error) {
    console.error('Error aplicando cambio de estado automático:', error);
    return {
      exito: false,
      mensaje: 'Error interno aplicando cambio de estado'
    };
  }
}

/**
 * Proceso de monitoreo automático de viajes
 * Esta función debe ejecutarse periódicamente (ej: cada 5 minutos)
 */
export async function procesarCambiosEstadoAutomaticos() {
  try {
    console.log('🔄 Iniciando procesamiento de cambios de estado automáticos...');
    
    // Buscar viajes activos que podrían necesitar cambio de estado
    const viajesActivos = await Viaje.find({
      estado: 'activo',
      fecha_ida: { $lte: new Date() } // Fecha de ida ya pasó
    });

    console.log(`📊 Encontrados ${viajesActivos.length} viajes activos que pasaron su hora de salida`);

    let procesados = 0;
    let cancelados = 0;
    let iniciados = 0;

    for (const viaje of viajesActivos) {
      const validacion = await validarCambioEstadoAutomatico(viaje._id.toString());
      
      if (validacion.valido) {
        const resultado = await aplicarCambioEstadoAutomatico(
          viaje._id.toString(),
          validacion.nuevoEstado,
          validacion.razon
        );
        
        if (resultado.exito) {
          procesados++;
          if (validacion.nuevoEstado === 'cancelado') {
            cancelados++;
          } else if (validacion.nuevoEstado === 'en_curso') {
            iniciados++;
          }
        }
      }
    }

    console.log(`✅ Procesamiento automático completado:
      - Viajes procesados: ${procesados}
      - Viajes cancelados: ${cancelados}
      - Viajes iniciados: ${iniciados}`);

    return {
      exito: true,
      procesados,
      cancelados,
      iniciados
    };

  } catch (error) {
    console.error('Error en procesamiento automático:', error);
    return {
      exito: false,
      mensaje: 'Error en procesamiento automático'
    };
  }
}
