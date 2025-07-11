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
      return handleErrorServer(res, 400, "Debe proporcionar exactamente 2 ubicaciones: origen y destino");
    }

    const origen = ubicaciones.find(u => u.esOrigen === true);
    const destino = ubicaciones.find(u => u.esOrigen === false);

    if (!origen || !destino) {
      return handleErrorServer(res, 400, "Debe especificar claramente el origen y destino");
    }

    // Verificar que el usuario existe en PostgreSQL
    const usuario = await userRepository.findOne({
      where: { rut: req.user.rut }
    });

    if (!usuario) {
      return handleErrorServer(res, 404, "Usuario no encontrado");
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
      return handleErrorServer(res, 404, "Vehículo no encontrado o no le pertenece");
    }

    // Validar fecha no sea pasada
    const fechaViajeIda = new Date(fechaIda);
    const ahora = new Date();
    ahora.setHours(0, 0, 0, 0);
    
    if (fechaViajeIda < ahora) {
      return handleErrorServer(res, 400, "No se pueden crear viajes en fechas pasadas");
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
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Buscar viajes por proximidad (radio de 500 metros)
 */
export async function buscarViajesPorProximidad(req, res) {
  try {
    const {
      origenLat,
      origenLng,
      destinoLat,
      destinoLng,
      fechaViaje,
      pasajeros = 1,
      radio = 2.0 // 2000 metros en kilómetros por defecto
    } = req.query;

    // Validar parámetros requeridos
    if (!origenLat || !origenLng || !destinoLat || !destinoLng || !fechaViaje) {
      return handleErrorServer(res, 400, "Parámetros requeridos: origenLat, origenLng, destinoLat, destinoLng, fechaViaje");
    }    // Convertir radio de kilómetros a metros (500 metros = 0.5 km)
    const radioEnMetros = parseFloat(radio) * 1000;

    console.log('🔍 Parámetros de búsqueda:');
    console.log('Origen:', { lat: origenLat, lng: origenLng });
    console.log('Destino:', { lat: destinoLat, lng: destinoLng });
    console.log('Fecha:', fechaViaje);
    console.log('Radio (metros):', radioEnMetros);

    // Fecha de búsqueda
    const fechaBusqueda = new Date(fechaViaje);
    const fechaInicio = new Date(fechaBusqueda);
    fechaInicio.setHours(0, 0, 0, 0);
    const fechaFin = new Date(fechaBusqueda);
    fechaFin.setHours(23, 59, 59, 999);

    console.log('Rango de fechas:', { inicio: fechaInicio, fin: fechaFin });

    // Primero verificar si hay viajes activos en la fecha
    const viajesEnFecha = await Viaje.find({
      estado: 'activo',
      fecha_ida: { $gte: fechaInicio, $lte: fechaFin },
      plazas_disponibles: { $gte: parseInt(pasajeros) }
    }).select('_id origen.ubicacion.coordinates destino.ubicacion.coordinates fecha_ida plazas_disponibles');    console.log('Viajes activos en la fecha:', viajesEnFecha.length);
    if (viajesEnFecha.length > 0) {
      console.log('Ejemplos de viajes en fecha:', viajesEnFecha.slice(0, 2).map(v => ({
        id: v._id,
        origen: v.origen?.ubicacion?.coordinates,
        destino: v.destino?.ubicacion?.coordinates,
        fecha: v.fecha_ida,
        plazas: v.plazas_disponibles
      })));
      
      // Calcular distancia manual para verificar
      const viajeEjemplo = viajesEnFecha[0];
      if (viajeEjemplo.origen?.ubicacion?.coordinates) {
        const viajeOrigenLng = viajeEjemplo.origen.ubicacion.coordinates[0];
        const viajeOrigenLat = viajeEjemplo.origen.ubicacion.coordinates[1];
        
        // Calcular distancia usando fórmula de Haversine
        const R = 6371000; // Radio de la Tierra en metros
        const dLat = (parseFloat(origenLat) - viajeOrigenLat) * Math.PI / 180;
        const dLng = (parseFloat(origenLng) - viajeOrigenLng) * Math.PI / 180;
        const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                  Math.cos(parseFloat(origenLat) * Math.PI / 180) * Math.cos(viajeOrigenLat * Math.PI / 180) *
                  Math.sin(dLng/2) * Math.sin(dLng/2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        const distancia = R * c;
        
        console.log('Distancia al viaje más cercano:', Math.round(distancia), 'metros');
        console.log('¿Está dentro del radio?', distancia <= radioEnMetros ? 'SÍ' : 'NO');
      }
    }    try {
      // Búsqueda con agregación para filtrar por proximidad de origen Y destino
      // Usamos fórmula de Haversine más robusta para evitar errores con coordenadas cercanas
      const viajes = await Viaje.aggregate([
      {
        $match: {
          estado: 'activo',
          fecha_ida: { $gte: fechaInicio, $lte: fechaFin },
          plazas_disponibles: { $gte: parseInt(pasajeros) }
        }
      },
      {
        $addFields: {
          // Calcular distancia al origen usando fórmula de Haversine
          distancia_origen: {
            $let: {
              vars: {
                lat1: { $degreesToRadians: { $toDouble: origenLat } },
                lat2: { $degreesToRadians: { $arrayElemAt: ['$origen.ubicacion.coordinates', 1] } },
                dlat: { $degreesToRadians: { $subtract: [{ $toDouble: origenLat }, { $arrayElemAt: ['$origen.ubicacion.coordinates', 1] }] } },
                dlon: { $degreesToRadians: { $subtract: [{ $toDouble: origenLng }, { $arrayElemAt: ['$origen.ubicacion.coordinates', 0] }] } }
              },
              in: {
                $multiply: [
                  6371000, // Radio de la Tierra en metros
                  {
                    $multiply: [
                      2,
                      {
                        $atan2: [
                          {
                            $sqrt: {
                              $add: [
                                {
                                  $pow: [{ $sin: { $divide: ['$$dlat', 2] } }, 2]
                                },
                                {
                                  $multiply: [
                                    { $cos: '$$lat1' },
                                    { $cos: '$$lat2' },
                                    { $pow: [{ $sin: { $divide: ['$$dlon', 2] } }, 2] }
                                  ]
                                }
                              ]
                            }
                          },
                          {
                            $sqrt: {
                              $subtract: [
                                1,
                                {
                                  $add: [
                                    {
                                      $pow: [{ $sin: { $divide: ['$$dlat', 2] } }, 2]
                                    },
                                    {
                                      $multiply: [
                                        { $cos: '$$lat1' },
                                        { $cos: '$$lat2' },
                                        { $pow: [{ $sin: { $divide: ['$$dlon', 2] } }, 2] }
                                      ]
                                    }
                                  ]
                                }
                              ]
                            }
                          }
                        ]
                      }
                    ]
                  }
                ]
              }
            }
          },
          // Calcular distancia al destino usando fórmula de Haversine
          distancia_destino: {
            $let: {
              vars: {
                lat1: { $degreesToRadians: { $toDouble: destinoLat } },
                lat2: { $degreesToRadians: { $arrayElemAt: ['$destino.ubicacion.coordinates', 1] } },
                dlat: { $degreesToRadians: { $subtract: [{ $toDouble: destinoLat }, { $arrayElemAt: ['$destino.ubicacion.coordinates', 1] }] } },
                dlon: { $degreesToRadians: { $subtract: [{ $toDouble: destinoLng }, { $arrayElemAt: ['$destino.ubicacion.coordinates', 0] }] } }
              },
              in: {
                $multiply: [
                  6371000, // Radio de la Tierra en metros
                  {
                    $multiply: [
                      2,
                      {
                        $atan2: [
                          {
                            $sqrt: {
                              $add: [
                                {
                                  $pow: [{ $sin: { $divide: ['$$dlat', 2] } }, 2]
                                },
                                {
                                  $multiply: [
                                    { $cos: '$$lat1' },
                                    { $cos: '$$lat2' },
                                    { $pow: [{ $sin: { $divide: ['$$dlon', 2] } }, 2] }
                                  ]
                                }
                              ]
                            }
                          },
                          {
                            $sqrt: {
                              $subtract: [
                                1,
                                {
                                  $add: [
                                    {
                                      $pow: [{ $sin: { $divide: ['$$dlat', 2] } }, 2]
                                    },
                                    {
                                      $multiply: [
                                        { $cos: '$$lat1' },
                                        { $cos: '$$lat2' },
                                        { $pow: [{ $sin: { $divide: ['$$dlon', 2] } }, 2] }
                                      ]
                                    }
                                  ]
                                }
                              ]
                            }
                          }
                        ]
                      }
                    ]
                  }
                ]
              }
            }
          }
        }
      },
      {
        $addFields: {
          // Calcular distancia total de caminata
          distancia_total: { $add: ['$distancia_origen', '$distancia_destino'] }
        }
      },      {
        $match: {
          // Filtrar viajes donde la distancia total de caminata sea razonable
          // O donde al menos una de las distancias esté muy cerca (dentro del radio original)
          $or: [
            // Opción 1: Distancia total de caminata menor a 4km
            { distancia_total: { $lte: radioEnMetros * 2 } },
            // Opción 2: Al menos una distancia está muy cerca (dentro del radio original)
            {
              $and: [
                { distancia_origen: { $lte: radioEnMetros } },
                { distancia_destino: { $lte: radioEnMetros * 1.5 } }
              ]
            },
            // Opción 3: Al menos una distancia está muy cerca (dentro del radio original)
            {
              $and: [
                { distancia_origen: { $lte: radioEnMetros * 1.5 } },
                { distancia_destino: { $lte: radioEnMetros } }
              ]
            }
          ]
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
          distancia_destino: { $round: ['$distancia_destino', 0] },
          distancia_total: { $round: ['$distancia_total', 0] }
        }
      },
      {
        $sort: { 
          distancia_total: 1, // Ordenar por distancia total ascendente
          fecha_ida: 1, 
          hora_ida: 1 
        }
      }
    ]);    console.log('📊 Resultados de agregación:');
    console.log('Viajes encontrados:', viajes.length);
    
    if (viajes.length > 0) {
      console.log('✅ Primer viaje encontrado:');
      const primerViaje = viajes[0];
      console.log('- ID:', primerViaje._id);
      console.log('- Distancia origen:', primerViaje.distancia_origen, 'metros');
      console.log('- Distancia destino:', primerViaje.distancia_destino, 'metros');
      console.log('- Distancia total:', primerViaje.distancia_total, 'metros');
      console.log('- ¿Dentro del radio?', primerViaje.distancia_total <= radioEnMetros ? 'SÍ' : 'NO');
    } else {
      console.log('❌ No se encontraron viajes que cumplan los criterios de proximidad');
    }

    // Enriquecer con datos de PostgreSQL
    const viajesConDatos = await Promise.all(
      viajes.map(async (viaje) => {
        const conductor = await userRepository.findOne({
          where: { rut: viaje.usuario_rut }
        });

        const vehiculo = await vehiculoRepository.findOne({
          where: { patente: viaje.vehiculo_patente },
          relations: ["propietario"]
        });        return {
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
          } : null,
          // Agregar información de distancias para mostrar al usuario
          distancias: {
            origenMetros: viaje.distancia_origen,
            destinoMetros: viaje.distancia_destino,
            totalMetros: viaje.distancia_total,
            origenTexto: `${Math.round(viaje.distancia_origen)}m caminando`,
            destinoTexto: `${Math.round(viaje.distancia_destino)}m caminando`,
            totalTexto: `${Math.round(viaje.distancia_total)}m total caminando`
          }
        };
      })
    );      handleSuccess(res, 200, `Se encontraron ${viajesConDatos.length} viajes disponibles`, {
        viajes: viajesConDatos,
        criterios_busqueda: {
          radio_metros: radioEnMetros,
          fecha: fechaViaje,
          pasajeros: pasajeros,
          origen: { lat: origenLat, lng: origenLng },
          destino: { lat: destinoLat, lng: destinoLng }
        }
      });

    } catch (aggregationError) {
      console.error('❌ Error en el pipeline de agregación:', aggregationError);
      return handleErrorServer(res, 500, "Error al procesar la búsqueda de viajes: " + aggregationError.message);
    }

  } catch (error) {
    console.error("Error en búsqueda por proximidad:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
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
    
    // COMENTAR TEMPORALMENTE el filtro de fecha para mostrar todos los viajes
    // Esto evita problemas de zona horaria que filtran incorrectamente los viajes
    /*
    if (fecha_desde || fecha_hasta) {
      filtroFecha.fecha_ida = {};
      if (fecha_desde) filtroFecha.fecha_ida.$gte = new Date(fecha_desde);
      if (fecha_hasta) filtroFecha.fecha_ida.$lte = new Date(fecha_hasta);
    } else {
      // Por defecto, solo viajes de hoy en adelante
      const hoy = new Date();
      // No establecer horas para evitar problemas de zona horaria
      const fechaHoy = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());
      filtroFecha.fecha_ida = { $gte: fechaHoy };
    }
    */

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
      return handleErrorServer(res, 404, "Viaje no encontrado");
    }

    // Validaciones
    if (viaje.estado !== 'activo') {
      return handleErrorServer(res, 400, "Este viaje ya no está disponible");
    }

    if (viaje.usuario_rut === usuarioRut) {
      return handleErrorServer(res, 400, "No puedes unirte a tu propio viaje");
    }

    if (viaje.plazas_disponibles < pasajeros_solicitados) {
      return handleErrorServer(res, 400, `Solo hay ${viaje.plazas_disponibles} plazas disponibles`);
    }

    // Verificar si ya se unió
    const yaUnido = viaje.pasajeros.some(p => 
      p.usuario_rut === usuarioRut
    );

    if (yaUnido) {
      return handleErrorServer(res, 400, "Ya tienes una solicitud pendiente para este viaje");
    }

    // Agregar solicitud de pasajero
    viaje.pasajeros.push({
      usuario_rut: usuarioRut,
      estado: 'confirmado', // Cambiado de 'pendiente' a 'confirmado' para simplificar
      pasajeros_solicitados: pasajeros_solicitados,
      mensaje: mensaje
    });

    // Reducir plazas disponibles temporalmente
    viaje.plazas_disponibles -= pasajeros_solicitados;

    await viaje.save();

    handleSuccess(res, 200, "Te has unido al viaje exitosamente", {
      estado: 'confirmado'
    });

  } catch (error) {
    console.error("Error al unirse a viaje:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Obtener viajes del usuario
 */
export async function obtenerViajesUsuario(req, res) {
  try {
    const usuarioRut = req.user.rut;
    console.log(`🔍 Buscando viajes para usuario: ${usuarioRut}`);

    // Obtener viajes creados por el usuario
    const viajesCreados = await Viaje.find({ usuario_rut: usuarioRut })
      .sort({ fecha_creacion: -1 });
    console.log(`📝 Viajes creados encontrados: ${viajesCreados.length}`);

    // Obtener viajes donde el usuario es pasajero (pendiente o confirmado)
    const viajesUnidos = await Viaje.find({
      "pasajeros.usuario_rut": usuarioRut,
      "pasajeros.estado": { $in: ["pendiente", "confirmado"] }
    }).sort({ fecha_creacion: -1 });
    console.log(`🚗 Viajes unidos encontrados: ${viajesUnidos.length}`);

    // Combinar y eliminar duplicados (por si acaso)
    const todosLosViajes = [];
    const viajesIds = new Set();

    // Agregar viajes creados
    for (const viaje of viajesCreados) {
      if (!viajesIds.has(viaje._id.toString())) {
        const viajeConDatos = await obtenerViajeConDatos(viaje._id);
        if (viajeConDatos) {
          viajeConDatos.es_creador = true;
          viajeConDatos.es_unido = false;
          todosLosViajes.push(viajeConDatos);
          viajesIds.add(viaje._id.toString());
        }
      }
    }

    // Agregar viajes a los que se unió
    for (const viaje of viajesUnidos) {
      if (!viajesIds.has(viaje._id.toString())) {
        const viajeConDatos = await obtenerViajeConDatos(viaje._id);
        if (viajeConDatos) {
          viajeConDatos.es_creador = false;
          viajeConDatos.es_unido = true;
          todosLosViajes.push(viajeConDatos);
          viajesIds.add(viaje._id.toString());
        }
      }
    }

    // Ordenar por fecha de creación (más reciente primero)
    todosLosViajes.sort((a, b) => new Date(b.fecha_creacion) - new Date(a.fecha_creacion));

    console.log(`✅ Total de viajes a enviar: ${todosLosViajes.length}`);
    console.log(`   - Creados: ${todosLosViajes.filter(v => v.es_creador).length}`);
    console.log(`   - Unidos: ${todosLosViajes.filter(v => v.es_unido).length}`);

    handleSuccess(res, 200, "Viajes obtenidos exitosamente", todosLosViajes);

  } catch (error) {
    console.error("Error al obtener viajes del usuario:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
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

/**
 * Función para cancelar un viaje
 */
export async function cancelarViaje(req, res) {
  try {
    const { viajeId } = req.params;
    const usuarioRut = req.user.rut;

    // Buscar el viaje
    const viaje = await Viaje.findById(viajeId);

    if (!viaje) {
      return handleErrorServer(res, "Viaje no encontrado");
    }

    // Validaciones
    if (viaje.usuario_rut !== usuarioRut) {
      return handleErrorServer(res, "Solo el creador del viaje puede cancelarlo");
    }

    if (viaje.estado !== 'activo') {
      return handleErrorServer(res, "Este viaje ya no está activo");
    }

    // Cambiar estado a cancelado
    viaje.estado = 'cancelado';
    viaje.plazas_disponibles = 0; // Todas las plazas quedan disponibles

    await viaje.save();

    handleSuccess(res, 200, "Viaje cancelado exitosamente");

  } catch (error) {
    console.error("Error al cancelar viaje:", error);
    handleErrorServer(res, "Error interno del servidor");
  }
}
/**
 * Función para eliminar un viaje
 */
export async function eliminarViaje(req, res) {
  try {
    const { viajeId } = req.params;
    const usuarioRut = req.user.rut;

    // Buscar el viaje
    const viaje = await Viaje.findById(viajeId);

    if (!viaje) {
      return handleErrorServer(res, "Viaje no encontrado");
    }

    // Validaciones
    if (viaje.usuario_rut !== usuarioRut) {
      return handleErrorServer(res, "Solo el creador del viaje puede eliminarlo");
    }

    // Eliminar el viaje
    await Viaje.deleteOne({ _id: viajeId });

    handleSuccess(res, 200, "Viaje eliminado exitosamente");

  } catch (error) {
    console.error("Error al eliminar viaje:", error);
    handleErrorServer(res, "Error interno del servidor");
  }
}

/**
 * Confirmar un pasajero en un viaje
 */
export async function confirmarPasajero(req, res) {
  try {
    const { viajeId, usuarioRut } = req.params;
    const conductorRut = req.user.rut;

    // Buscar el viaje
    const viaje = await Viaje.findById(viajeId);

    if (!viaje) {
      return handleErrorServer(res, "Viaje no encontrado");
    }

    // Verificar que el usuario autenticado es el conductor del viaje
    if (viaje.usuario_rut !== conductorRut) {
      return handleErrorServer(res, "Solo el conductor puede confirmar pasajeros");
    }

    // Buscar el pasajero en la lista
    const pasajeroIndex = viaje.pasajeros.findIndex(p => p.usuario_rut === usuarioRut);

    if (pasajeroIndex === -1) {
      return handleErrorServer(res, "Pasajero no encontrado en este viaje");
    }

    const pasajero = viaje.pasajeros[pasajeroIndex];

    if (pasajero.estado === 'confirmado') {
      return handleErrorServer(res, "El pasajero ya está confirmado");
    }

    if (pasajero.estado === 'rechazado') {
      return handleErrorServer(res, "No se puede confirmar un pasajero rechazado");
    }

    // Confirmar el pasajero
    viaje.pasajeros[pasajeroIndex].estado = 'confirmado';
    await viaje.save();

    handleSuccess(res, 200, "Pasajero confirmado exitosamente", {
      usuarioRut: usuarioRut,
      estado: 'confirmado'
    });

  } catch (error) {
    console.error("Error al confirmar pasajero:", error);
    handleErrorServer(res, "Error interno del servidor");
  }
}