"use strict";
import Viaje from "../entity/viaje.entity.js";
import { AppDataSource } from "../config/configDb.js";
import { crearNotificacionService, obtenerNotificacionesService } from "./notificacion.service.js";
import { convertirFechaChile, obtenerFechaActualChile } from "../utils/dateChile.js";

const userRepository = AppDataSource.getRepository("User");

/**
 * Calcular la distancia en kilómetros entre dos puntos geográficos usando la fórmula de Haversine
 * @param {number} lat1 - Latitud del primer punto
 * @param {number} lon1 - Longitud del primer punto
 * @param {number} lat2 - Latitud del segundo punto
 * @param {number} lon2 - Longitud del segundo punto
 * @returns {number} Distancia en kilómetros
 */
function calcularDistanciaKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radio de la Tierra en kilómetros
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  const distancia = R * c;
  
  return Math.round(distancia * 100) / 100; // Redondear a 2 decimales
}

/**
 * Calcular distancia por carretera usando factor de corrección basado en Haversine
 * @param {number} lat1 - Latitud del primer punto
 * @param {number} lon1 - Longitud del primer punto
 * @param {number} lat2 - Latitud del segundo punto
 * @param {number} lon2 - Longitud del segundo punto
 * @returns {number} Distancia estimada por carretera en kilómetros
 */
function calcularDistanciaCarretera(lat1, lon1, lat2, lon2) {
  // Primero calcular distancia en línea recta usando Haversine
  const distanciaLineal = calcularDistanciaKm(lat1, lon1, lat2, lon2);
  
  // Factor de corrección según distancia (basado en estadísticas reales de Chile)
  let factor = 1.2; // 20% más por defecto
  
  if (distanciaLineal < 5) {
    factor = 1.6; // Ciudades: +60% (muchas vueltas)
  } else if (distanciaLineal < 15) {
    factor = 1.4; // Urbano: +40%
  } else if (distanciaLineal < 50) {
    factor = 1.3; // Regional: +30%
  } else if (distanciaLineal < 200) {
    factor = 1.2; // Interprovincial: +20%
  } else {
    factor = 1.15; // Larga distancia: +15% (autopistas más directas)
  }
  
  return distanciaLineal * factor;
}

/**
 * Calcular tiempo estimado de viaje basado en distancia y tipo de terreno
 * @param {number} distanciaKm - Distancia en kilómetros
 * @returns {number} Tiempo estimado en minutos
 */
function calcularTiempoEstimado(distanciaKm) {
  let velocidadPromedio;
  
  if (distanciaKm < 3) {
    velocidadPromedio = 15; // Centro ciudad: 15 km/h
  } else if (distanciaKm < 8) {
    velocidadPromedio = 20; // Ciudad: 20 km/h
  } else if (distanciaKm < 20) {
    velocidadPromedio = 30; // Urbano/suburbano: 30 km/h
  } else if (distanciaKm < 50) {
    velocidadPromedio = 55; // Regional: 55 km/h
  } else if (distanciaKm < 150) {
    velocidadPromedio = 75; // Interprovincial: 75 km/h
  } else {
    velocidadPromedio = 85; // Larga distancia: 85 km/h
  }
  
  return Math.round((distanciaKm / velocidadPromedio) * 60); // Convertir a minutos
}

/**
 * Validar si un conductor puede publicar un viaje durante el tiempo estimado de viajes a los que está unido
 * @param {String} usuarioRut - RUT del usuario (conductor)
 * @param {Object} nuevoViaje - Datos del nuevo viaje {fechaHoraIda, origen, destino}
 * @returns {Object} - Resultado de la validación
 */
export async function validarPublicacionConductor(usuarioRut, nuevoViaje) {
  try {
    console.log('🚗 Validando publicación de conductor durante viajes unidos...');
    
    // Obtener viajes donde el usuario está como PASAJERO (unidos)
    const viajesComoUnido = await Viaje.find({
      'pasajeros.usuario_rut': usuarioRut,
      'pasajeros.estado': { $in: ['confirmado', 'pendiente'] },
      estado: { $in: ['activo', 'en_curso'] }
    });
    
    const nuevaFechaIda = convertirFechaChile(nuevoViaje.fechaHoraIda);
    const nuevoOrigenLat = nuevoViaje.origen.lat;
    const nuevoOrigenLng = nuevoViaje.origen.lon;
    const nuevoDestinoLat = nuevoViaje.destino.lat;
    const nuevoDestinoLng = nuevoViaje.destino.lon;
    
    // Calcular duración estimada del nuevo viaje
    const distanciaNueva = calcularDistanciaCarretera(nuevoOrigenLat, nuevoOrigenLng, nuevoDestinoLat, nuevoDestinoLng);
    const duracionNueva = calcularTiempoEstimado(distanciaNueva);
    const finNuevoViaje = new Date(nuevaFechaIda.getTime() + (duracionNueva * 60 * 1000));
    
    for (const viajeUnido of viajesComoUnido) {
      const fechaInicioUnido = convertirFechaChile(viajeUnido.fecha_ida);
      
      // Calcular duración del viaje al que está unido
      const distanciaUnido = calcularDistanciaCarretera(
        viajeUnido.origen.lat, viajeUnido.origen.lon,
        viajeUnido.destino.lat, viajeUnido.destino.lon
      );
      const duracionUnido = calcularTiempoEstimado(distanciaUnido);
      const finViajeUnido = new Date(fechaInicioUnido.getTime() + (duracionUnido * 60 * 1000));
      
      // Verificar solapamiento temporal
      const inicioNuevo = nuevaFechaIda.getTime();
      const finNuevo = finNuevoViaje.getTime();
      const inicioUnido = fechaInicioUnido.getTime();
      const finUnido = finViajeUnido.getTime();
      
      const haySolapamiento = (inicioNuevo < finUnido) && (finNuevo > inicioUnido);
      
      if (haySolapamiento) {
        // Corregir horario sumando 4 horas para mostrar hora de Chile correcta
        const fechaMostrar = new Date(fechaInicioUnido.getTime() + (4 * 60 * 60 * 1000));
        
        return {
          valido: false,
          razon: `No puedes publicar un viaje durante el horario de un viaje al que estás unido. Viaje del ${fechaMostrar.toLocaleDateString('es-CL')} a las ${fechaMostrar.toLocaleTimeString('es-CL', { hour: '2-digit', minute: '2-digit' })}`,
          tipoConflicto: 'conductor_unido_a_viaje',
          viajeConflicto: viajeUnido._id
        };
      }
    }
    
    return { valido: true };
    
  } catch (error) {
    console.error('Error al validar publicación de conductor:', error);
    return {
      valido: false,
      razon: 'Error interno al validar conflictos de conductor'
    };
  }
}

/**
 * Validar conflictos de viajes considerando tiempos de traslado
 * @param {String} usuarioRut - RUT del usuario
 * @param {Object} nuevoViaje - Datos del nuevo viaje {fechaHoraIda, origen, destino}
 * @param {String} viajeExcluidoId - ID del viaje a excluir (para ediciones)
 * @returns {Object} - Resultado de la validación
 */
export async function validarConflictosConTiempo(usuarioRut, nuevoViaje, viajeExcluidoId = null) {
  try {
    console.log('🕒 Validando conflictos con tiempo de traslado...');
    
    // Obtener viajes activos y en curso del usuario
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

    if (viajeExcluidoId) {
      filtroBase._id = { $ne: viajeExcluidoId };
    }

    const viajesExistentes = await Viaje.find(filtroBase);
    
    const nuevaFechaIda = convertirFechaChile(nuevoViaje.fechaHoraIda);
    const nuevoOrigenLat = nuevoViaje.origen.lat;
    const nuevoOrigenLng = nuevoViaje.origen.lon;
    const nuevoDestinoLat = nuevoViaje.destino.lat;
    const nuevoDestinoLng = nuevoViaje.destino.lon;
    
    // Calcular duración del nuevo viaje
    const distanciaNuevoViaje = calcularDistanciaCarretera(nuevoOrigenLat, nuevoOrigenLng, nuevoDestinoLat, nuevoDestinoLng);
    const duracionNuevoViaje = calcularTiempoEstimado(distanciaNuevoViaje);
    const finNuevoViaje = new Date(nuevaFechaIda.getTime() + (duracionNuevoViaje * 60 * 1000));

    console.log(`📊 Nuevo viaje: ${nuevaFechaIda.toISOString()} (duración: ${duracionNuevoViaje} min)`);

    for (const viajeExistente of viajesExistentes) {
      const fechaExistente = convertirFechaChile(viajeExistente.fecha_ida);
      const origenExistenteLat = viajeExistente.origen.ubicacion.coordinates[1];
      const origenExistenteLng = viajeExistente.origen.ubicacion.coordinates[0];
      const destinoExistenteLat = viajeExistente.destino.ubicacion.coordinates[1];
      const destinoExistenteLng = viajeExistente.destino.ubicacion.coordinates[0];
      
      // Calcular duración del viaje existente
      const distanciaExistente = calcularDistanciaCarretera(
        origenExistenteLat, origenExistenteLng, 
        destinoExistenteLat, destinoExistenteLng
      );
      const duracionExistente = calcularTiempoEstimado(distanciaExistente);
      const finViajeExistente = new Date(fechaExistente.getTime() + (duracionExistente * 60 * 1000));

      // VERIFICACIÓN 1: Solapamiento temporal directo
      const inicioNuevo = nuevaFechaIda.getTime();
      const finNuevo = finNuevoViaje.getTime();
      const inicioExistente = fechaExistente.getTime();
      const finExistente = finViajeExistente.getTime();

      const haySolapamiento = (inicioNuevo < finExistente) && (finNuevo > inicioExistente);

      if (haySolapamiento) {
        // Corregir horario sumando 4 horas para mostrar hora de Chile correcta
        const fechaMostrar = new Date(fechaExistente.getTime() + (4 * 60 * 60 * 1000));
        
        return {
          valido: false,
          razon: `Conflicto temporal: El nuevo viaje se solapa con un viaje existente del ${fechaMostrar.toLocaleDateString('es-CL')} a las ${fechaMostrar.toLocaleTimeString('es-CL', { hour: '2-digit', minute: '2-digit' })}`,
          tipoConflicto: 'solapamiento_temporal',
          viajeConflicto: viajeExistente._id
        };
      }

      // VERIFICACIÓN 2: Tiempo de traslado insuficiente
      let conflictoTraslado = false;
      let mensajeTraslado = '';
      let tiempoTotalNecesario = 0;
      let tiempoDisponible = 0;

      // Caso A: El nuevo viaje es DESPUÉS del existente
      if (inicioNuevo > finExistente) {
        // ¿Puede llegar desde el destino del viaje existente al origen del nuevo viaje?
        const distanciaTraslado = calcularDistanciaCarretera(
          destinoExistenteLat, destinoExistenteLng,
          nuevoOrigenLat, nuevoOrigenLng
        );
        const tiempoTraslado = calcularTiempoEstimado(distanciaTraslado);
        const tiempoBuffer = 10; // 10 minutos de buffer mínimo
        tiempoTotalNecesario = tiempoTraslado + tiempoBuffer;
        
        tiempoDisponible = (inicioNuevo - finExistente) / (1000 * 60); // en minutos

        if (tiempoDisponible < tiempoTotalNecesario) {
          conflictoTraslado = true;
          mensajeTraslado = `No hay tiempo suficiente para trasladarse desde el destino del viaje anterior (${viajeExistente.destino.nombre}) al origen del nuevo viaje (${nuevoViaje.origen.displayName}). Necesitas ${tiempoTotalNecesario} minutos pero solo tienes ${Math.round(tiempoDisponible)} minutos disponibles.`;
        }
      }

      // Caso B: El nuevo viaje es ANTES del existente
      if (finNuevo < inicioExistente) {
        const distanciaTraslado = calcularDistanciaCarretera(
          nuevoDestinoLat, nuevoDestinoLng,
          origenExistenteLat, origenExistenteLng
        );
        const tiempoTraslado = calcularTiempoEstimado(distanciaTraslado);
        const tiempoBuffer = 10; // 10 minutos de buffer
        tiempoTotalNecesario = tiempoTraslado + tiempoBuffer;
        
        tiempoDisponible = (inicioExistente - finNuevo) / (1000 * 60);

        if (tiempoDisponible < tiempoTotalNecesario) {
          conflictoTraslado = true;
          mensajeTraslado = `No hay tiempo suficiente para trasladarse desde el destino del nuevo viaje (${nuevoViaje.destino.displayName}) al origen del viaje siguiente (${viajeExistente.origen.nombre}). Necesitas ${tiempoTotalNecesario} minutos pero solo tienes ${Math.round(tiempoDisponible)} minutos disponibles.`;
        }
      }

      if (conflictoTraslado) {
        return {
          valido: false,
          razon: mensajeTraslado,
          tipoConflicto: 'tiempo_traslado_insuficiente',
          viajeConflicto: viajeExistente._id,
          tiempoNecesario: tiempoTotalNecesario,
          tiempoDisponible: Math.round(tiempoDisponible)
        };
      }
    }

    return {
      valido: true,
      razon: 'No hay conflictos de tiempo'
    };

  } catch (error) {
    console.error('Error validando conflictos con tiempo:', error);
    return {
      valido: false,
      razon: 'Error interno en la validación de conflictos'
    };
  }
}

/**
 * Validar que un usuario no tenga múltiples viajes en curso simultáneamente
 * @param {String} usuarioRut - RUT del usuario
 * @param {String} viajeExcluidoId - ID del viaje a excluir (opcional)
 * @returns {Object} - Resultado de la validación
 */
export async function validarConflictosViajesEnCurso(usuarioRut, viajeExcluidoId = null) {
  try {
    // Buscar viajes en curso del usuario
    const filtroViajesEnCurso = {
      $or: [
        { usuario_rut: usuarioRut }, // Como conductor
        { 
          'pasajeros.usuario_rut': usuarioRut,
          'pasajeros.estado': 'confirmado'
        } // Como pasajero confirmado
      ],
      estado: 'en_curso'
    };

    if (viajeExcluidoId) {
      filtroViajesEnCurso._id = { $ne: viajeExcluidoId };
    }

    const viajesEnCurso = await Viaje.find(filtroViajesEnCurso);

    if (viajesEnCurso.length > 0) {
      const viajeConflicto = viajesEnCurso[0];
      return {
        valido: false,
        razon: `El usuario ya tiene un viaje en curso desde ${viajeConflicto.origen.nombre} hacia ${viajeConflicto.destino.nombre}`,
        viajeConflicto: viajeConflicto._id
      };
    }

    return {
      valido: true,
      razon: 'No hay conflictos con viajes en curso'
    };

  } catch (error) {
    console.error('Error validando conflictos de viajes en curso:', error);
    return {
      valido: false,
      razon: 'Error interno validando viajes en curso'
    };
  }
}

/**
 * Validar si un viaje puede cambiar automáticamente de estado
 * MODIFICADO: Cancelar si no hay pasajeros confirmados y verificar conflictos en_curso
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

    if (viaje.estado === 'activo') {
      const now = obtenerFechaActualChile();
      const fechaIda = convertirFechaChile(viaje.fecha_ida);
      
      // Si ya pasó la hora de salida (+5 minutos de gracia)
      if (now >= fechaIda.getTime() + (5 * 60 * 1000)) {
        const pasajerosConfirmados = viaje.pasajeros.filter(p => p.estado === 'confirmado');
        
        // NUEVA REGLA: Cancelar automáticamente si no hay pasajeros confirmados
        if (pasajerosConfirmados.length === 0) {
          return {
            valido: true,
            nuevoEstado: 'cancelado',
            razon: 'Viaje cancelado automáticamente: sin pasajeros confirmados a la hora de salida'
          };
        }
        
        // NUEVA VALIDACIÓN: Verificar que no hay conflictos con otros viajes en_curso
        const conflictosEnCurso = await validarConflictosViajesEnCurso(viaje.usuario_rut, viaje._id);
        
        if (!conflictosEnCurso.valido) {
          return {
            valido: true,
            nuevoEstado: 'cancelado',
            razon: `Viaje cancelado automáticamente: ${conflictosEnCurso.razon}`
          };
        }
        
        // Si hay pasajeros confirmados y no hay conflictos, iniciar viaje
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
 * MODIFICADO: Verificar que no hay conflictos con viajes en curso y que hay pasajeros
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

    // NUEVA VALIDACIÓN: Verificar que hay al menos un pasajero confirmado
    const pasajerosConfirmados = viaje.pasajeros.filter(p => p.estado === 'confirmado');
    
    if (pasajerosConfirmados.length === 0) {
      return {
        valido: false,
        razon: 'No puedes iniciar un viaje sin pasajeros confirmados. El viaje debe ser cancelado.'
      };
    }

    // NUEVA VALIDACIÓN: Verificar que no hay conflictos con otros viajes en curso
    const conflictosEnCurso = await validarConflictosViajesEnCurso(conductorRut, viajeId);
    
    if (!conflictosEnCurso.valido) {
      return {
        valido: false,
        razon: `No puedes iniciar este viaje: ${conflictosEnCurso.razon}`
      };
    }

    // Validación 3: Verificar que no hay notificaciones pendientes
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
