"use strict";
import Viaje from "../entity/viaje.entity.js";
import { AppDataSource } from "../config/configDb.js";
import { handleErrorServer, handleSuccess } from "../handlers/responseHandlers.js";

// Obtener repositorios de PostgreSQL
const userRepository = AppDataSource.getRepository("User");
const vehiculoRepository = AppDataSource.getRepository("Vehiculo");

/**
 * Crear un nuevo viaje
 */
export async function crearViaje(req, res) {
  try {
    const {
      ubicaciones,
      fechaIda,
      horaIda,
      fechaVuelta,
      horaVuelta,
      viajeIdaYVuelta,
      maxPasajeros,
      soloMujeres,
      flexibilidadSalida,
      precio,
      plazasDisponibles,
      comentarios,
      vehiculoPatente
    } = req.body;

    // Validar que hay exactamente 2 ubicaciones
    if (!ubicaciones || ubicaciones.length !== 2) {
      return handleErrorServer(res, "Debe proporcionar exactamente 2 ubicaciones: origen y destino");
    }

    const origen = ubicaciones.find(u => u.esOrigen === true);
    const destino = ubicaciones.find(u => u.esOrigen === false);

    if (!origen || !destino) {
      return handleErrorServer(res, "Debe especificar claramente el origen y destino");
    }

    // Verificar que el usuario existe en PostgreSQL
    const usuario = await userRepository.findOne({
      where: { rut: req.user.rut }
    });

    if (!usuario) {
      return handleErrorServer(res, "Usuario no encontrado");
    }

    // Verificar que el vehículo existe y pertenece al usuario
    const vehiculo = await vehiculoRepository.findOne({
      where: { 
        patente: vehiculoPatente,
        propietario: { rut: req.user.rut }
      },
      relations: ["propietario"]
    });

    if (!vehiculo) {
      return handleErrorServer(res, "Vehículo no encontrado o no le pertenece");
    }

    // Validar fecha no sea pasada
    const fechaViajeIda = new Date(fechaIda);
    const ahora = new Date();
    ahora.setHours(0, 0, 0, 0);
    
    if (fechaViajeIda < ahora) {
      return handleErrorServer(res, "No se pueden crear viajes en fechas pasadas");
    }

    // Crear el viaje en MongoDB
    const nuevoViaje = new Viaje({
      usuario_rut: req.user.rut,
      origen: {
        nombre: origen.displayName,
        ubicacion: {
          type: 'Point',
          coordinates: [origen.lon, origen.lat] // [longitud, latitud]
        }
      },
      destino: {
        nombre: destino.displayName,
        ubicacion: {
          type: 'Point',
          coordinates: [destino.lon, destino.lat]
        }
      },
      fecha_ida: new Date(fechaIda),
      hora_ida: horaIda,
      fecha_vuelta: fechaVuelta ? new Date(fechaVuelta) : null,
      hora_vuelta: horaVuelta,
      viaje_ida_vuelta: viajeIdaYVuelta,
      max_pasajeros: maxPasajeros,
      solo_mujeres: soloMujeres,
      flexibilidad_salida: flexibilidadSalida,
      precio: precio,
      plazas_disponibles: plazasDisponibles,
      comentarios: comentarios,
      vehiculo_patente: vehiculoPatente
    });

    await nuevoViaje.save();

    // Obtener datos completos para la respuesta
    const viajeCompleto = await obtenerViajeConDatos(nuevoViaje._id);

    handleSuccess(res, 201, "Viaje creado exitosamente", viajeCompleto);

  } catch (error) {
    console.error("Error al crear viaje:", error);
    handleErrorServer(res, "Error interno del servidor");
  }
}

/**
 * Buscar viajes por proximidad (radio de 500 metros)
 */
export async function buscarViajesPorProximidad(req, res) {
  try {
    const {
      origen_lat,
      origen_lon,
      destino_lat,
      destino_lon,
      fecha,
      pasajeros = 1,
      radio = 0.5 // 500 metros en kilómetros
    } = req.query;

    // Validar parámetros requeridos
    if (!origen_lat || !origen_lon || !destino_lat || !destino_lon || !fecha) {
      return handleErrorServer(res, "Parámetros requeridos: origen_lat, origen_lon, destino_lat, destino_lon, fecha");
    }

    // Convertir radio de kilómetros a metros
    const radioEnMetros = parseFloat(radio) * 1000;

    // Fecha de búsqueda
    const fechaBusqueda = new Date(fecha);
    const fechaInicio = new Date(fechaBusqueda);
    fechaInicio.setHours(0, 0, 0, 0);
    const fechaFin = new Date(fechaBusqueda);
    fechaFin.setHours(23, 59, 59, 999);

    // Búsqueda con agregación para filtrar por proximidad de origen Y destino
    const viajes = await Viaje.aggregate([
      {
        $geoNear: {
          near: {
            type: 'Point',
            coordinates: [parseFloat(origen_lon), parseFloat(origen_lat)]
          },
          distanceField: 'distancia_origen',
          maxDistance: radioEnMetros,
          spherical: true
        }
      },
      {
        $addFields: {
          distancia_destino: {
            $let: {
              vars: {
                dlat: { $subtract: [{ $toDouble: destino_lat }, { $arrayElemAt: ['$destino.ubicacion.coordinates', 1] }] },
                dlon: { $subtract: [{ $toDouble: destino_lon }, { $arrayElemAt: ['$destino.ubicacion.coordinates', 0] }] }
              },
              in: {
                $multiply: [
                  6371000, // Radio de la Tierra en metros
                  {
                    $acos: {
                      $add: [
                        {
                          $multiply: [
                            { $cos: { $degreesToRadians: { $toDouble: destino_lat } } },
                            { $cos: { $degreesToRadians: { $arrayElemAt: ['$destino.ubicacion.coordinates', 1] } } },
                            { $cos: { $degreesToRadians: '$$dlon' } }
                          ]
                        },
                        {
                          $multiply: [
                            { $sin: { $degreesToRadians: { $toDouble: destino_lat } } },
                            { $sin: { $degreesToRadians: { $arrayElemAt: ['$destino.ubicacion.coordinates', 1] } } }
                          ]
                        }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      },
      {
        $match: {
          estado: 'activo',
          fecha_ida: { $gte: fechaInicio, $lte: fechaFin },
          plazas_disponibles: { $gte: parseInt(pasajeros) },
          distancia_destino: { $lte: radioEnMetros },
          usuario_rut: { $ne: req.user.rut } // Excluir viajes propios
        }
      },
      {
        $project: {
          _id: 1,
          usuario_rut: 1,
          vehiculo_patente: 1,
          origen: 1,
          destino: 1,
          fecha_ida: 1,
          hora_ida: 1,
          precio: 1,
          plazas_disponibles: 1,
          max_pasajeros: 1,
          comentarios: 1,
          flexibilidad_salida: 1,
          solo_mujeres: 1,
          distancia_origen: { $round: ['$distancia_origen', 0] },
          distancia_destino: { $round: ['$distancia_destino', 0] }
        }
      },
      {
        $sort: { fecha_ida: 1, hora_ida: 1 }
      }
    ]);

    // Enriquecer con datos de PostgreSQL
    const viajesConDatos = await Promise.all(
      viajes.map(async (viaje) => {
        const conductor = await userRepository.findOne({
          where: { rut: viaje.usuario_rut }
        });

        const vehiculo = await vehiculoRepository.findOne({
          where: { patente: viaje.vehiculo_patente },
          relations: ["propietario"]
        });

        return {
          ...viaje,
          conductor: conductor ? {
            rut: conductor.rut,
            nombre: conductor.nombreCompleto,
            email: conductor.email
          } : null,
          vehiculo: vehiculo ? {
            patente: vehiculo.patente,
            modelo: vehiculo.modelo,
            color: vehiculo.color,
            nro_asientos: vehiculo.nro_asientos
          } : null
        };
      })
    );

    handleSuccess(res, 200, `Se encontraron ${viajesConDatos.length} viajes disponibles`, {
      viajes: viajesConDatos,
      criterios_busqueda: {
        radio_metros: radioEnMetros,
        fecha: fecha,
        pasajeros: pasajeros,
        origen: { lat: origen_lat, lon: origen_lon },
        destino: { lat: destino_lat, lon: destino_lon }
      }
    });

  } catch (error) {
    console.error("Error en búsqueda por proximidad:", error);
    handleErrorServer(res, "Error interno del servidor");
  }
}

/**
 * Obtener viajes para mostrar en el mapa
 */
export async function obtenerViajesParaMapa(req, res) {
  try {
    const {
      fecha_desde,
      fecha_hasta
    } = req.query;

    let filtroFecha = { estado: 'activo', plazas_disponibles: { $gt: 0 } };
    
    if (fecha_desde || fecha_hasta) {
      filtroFecha.fecha_ida = {};
      if (fecha_desde) filtroFecha.fecha_ida.$gte = new Date(fecha_desde);
      if (fecha_hasta) filtroFecha.fecha_ida.$lte = new Date(fecha_hasta);
    } else {
      // Por defecto, solo viajes de hoy en adelante
      const hoy = new Date();
      hoy.setHours(0, 0, 0, 0);
      filtroFecha.fecha_ida = { $gte: hoy };
    }

    const viajes = await Viaje.find(filtroFecha)
      .select({
        _id: 1,
        usuario_rut: 1,
        vehiculo_patente: 1,
        origen: 1,
        destino: 1,
        fecha_ida: 1,
        hora_ida: 1,
        precio: 1,
        plazas_disponibles: 1
      })
      .sort({ fecha_ida: 1 });

    // Enriquecer con datos de PostgreSQL para el mapa
    const marcadores = await Promise.all(
      viajes.map(async (viaje) => {
        const conductor = await userRepository.findOne({
          where: { rut: viaje.usuario_rut }
        });

        const vehiculo = await vehiculoRepository.findOne({
          where: { patente: viaje.vehiculo_patente }
        });

        return {
          id: viaje._id,
          origen: {
            coordinates: viaje.origen.ubicacion.coordinates,
            nombre: viaje.origen.nombre
          },
          destino: {
            coordinates: viaje.destino.ubicacion.coordinates,
            nombre: viaje.destino.nombre
          },
          detalles_viaje: {
            fecha: viaje.fecha_ida,
            hora: viaje.hora_ida,
            precio: viaje.precio,
            plazas_disponibles: viaje.plazas_disponibles,
            vehiculo: vehiculo ? {
              patente: vehiculo.patente,
              modelo: vehiculo.modelo,
              color: vehiculo.color,
              nro_asientos: vehiculo.nro_asientos,
              tipo: obtenerTipoVehiculo(vehiculo.modelo) // Función helper
            } : null,
            conductor: conductor ? {
              rut: conductor.rut,
              nombre: conductor.nombreCompleto
            } : null
          }
        };
      })
    );

    handleSuccess(res, 200, `${marcadores.length} viajes disponibles en el mapa`, {
      marcadores: marcadores
    });

  } catch (error) {
    console.error("Error al obtener viajes para mapa:", error);
    handleErrorServer(res, "Error interno del servidor");
  }
}

/**
 * Unirse a un viaje
 */
export async function unirseAViaje(req, res) {
  try {
    const { viajeId } = req.params;
    const { pasajeros_solicitados = 1, mensaje } = req.body;
    const usuarioRut = req.user.rut;

    // Buscar el viaje
    const viaje = await Viaje.findById(viajeId);

    if (!viaje) {
      return handleErrorServer(res, "Viaje no encontrado");
    }

    // Validaciones
    if (viaje.estado !== 'activo') {
      return handleErrorServer(res, "Este viaje ya no está disponible");
    }

    if (viaje.usuario_rut === usuarioRut) {
      return handleErrorServer(res, "No puedes unirte a tu propio viaje");
    }

    if (viaje.plazas_disponibles < pasajeros_solicitados) {
      return handleErrorServer(res, `Solo hay ${viaje.plazas_disponibles} plazas disponibles`);
    }

    // Verificar si ya se unió
    const yaUnido = viaje.pasajeros.some(p => 
      p.usuario_rut === usuarioRut
    );

    if (yaUnido) {
      return handleErrorServer(res, "Ya tienes una solicitud pendiente para este viaje");
    }

    // Agregar solicitud de pasajero
    viaje.pasajeros.push({
      usuario_rut: usuarioRut,
      estado: 'pendiente',
      pasajeros_solicitados: pasajeros_solicitados,
      mensaje: mensaje
    });

    // Reducir plazas disponibles temporalmente
    viaje.plazas_disponibles -= pasajeros_solicitados;

    await viaje.save();

    handleSuccess(res, 200, "Solicitud enviada exitosamente", {
      estado: 'pendiente'
    });

  } catch (error) {
    console.error("Error al unirse a viaje:", error);
    handleErrorServer(res, "Error interno del servidor");
  }
}

/**
 * Obtener viajes del usuario
 */
export async function obtenerViajesUsuario(req, res) {
  try {
    const usuarioRut = req.user.rut;

    const viajes = await Viaje.find({ usuario_rut: usuarioRut })
      .sort({ fecha_creacion: -1 });

    // Enriquecer con datos de PostgreSQL
    const viajesConDatos = await Promise.all(
      viajes.map(async (viaje) => obtenerViajeConDatos(viaje._id))
    );

    handleSuccess(res, 200, "Viajes obtenidos exitosamente", viajesConDatos);

  } catch (error) {
    console.error("Error al obtener viajes del usuario:", error);
    handleErrorServer(res, "Error interno del servidor");
  }
}

/**
 * Función helper para obtener tipo de vehículo basado en modelo
 */
function obtenerTipoVehiculo(modelo) {
  const modeloLower = modelo.toLowerCase();
  
  if (modeloLower.includes('sedan') || modeloLower.includes('corolla') || modeloLower.includes('civic')) {
    return 'Sedan';
  } else if (modeloLower.includes('suv') || modeloLower.includes('rav4') || modeloLower.includes('crv')) {
    return 'SUV';
  } else if (modeloLower.includes('hatchback') || modeloLower.includes('yaris') || modeloLower.includes('fit')) {
    return 'Hatchback';
  } else {
    return 'Otro';
  }
}

/**
 * Función helper para obtener viaje con datos completos
 */
async function obtenerViajeConDatos(viajeId) {
  const viaje = await Viaje.findById(viajeId);
  
  if (!viaje) return null;

  const conductor = await userRepository.findOne({
    where: { rut: viaje.usuario_rut }
  });

  const vehiculo = await vehiculoRepository.findOne({
    where: { patente: viaje.vehiculo_patente }
  });

  // Obtener datos de pasajeros
  const pasajerosConDatos = await Promise.all(
    viaje.pasajeros.map(async (pasajero) => {
      const usuarioPasajero = await userRepository.findOne({
        where: { rut: pasajero.usuario_rut }
      });
      
      return {
        ...pasajero.toObject(),
        usuario: usuarioPasajero ? {
          rut: usuarioPasajero.rut,
          nombre: usuarioPasajero.nombreCompleto,
          email: usuarioPasajero.email
        } : null
      };
    })
  );

  return {
    ...viaje.toObject(),
    conductor: conductor ? {
      rut: conductor.rut,
      nombre: conductor.nombreCompleto,
      email: conductor.email
    } : null,
    vehiculo: vehiculo ? {
      patente: vehiculo.patente,
      modelo: vehiculo.modelo,
      color: vehiculo.color,
      nro_asientos: vehiculo.nro_asientos,
      tipo: obtenerTipoVehiculo(vehiculo.modelo)
    } : null,
    pasajeros: pasajerosConDatos
  };
}
