"use strict";
import Viaje from "../entity/viaje.entity.js";
import { AppDataSource } from "../config/configDb.js";
import { handleErrorServer, handleSuccess } from "../handlers/responseHandlers.js";
import { crearChatGrupal, agregarParticipante, eliminarParticipante, finalizarChatGrupal } from "../services/chatGrupal.service.js";
import { 
  notificarChatGrupalCreado, 
  notificarParticipanteAgregado, 
  notificarParticipanteEliminado, 
  notificarChatGrupalFinalizado 
} from "../socket.js";

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
      fechaHoraIda,
      fechaHoraVuelta,
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

    // Validar fecha y hora no sea pasada - usar zona horaria de Chile
    console.log("📅 DEBUG - Fecha y hora de ida recibida:", fechaHoraIda);
    if (viajeIdaYVuelta && fechaHoraVuelta) {
      console.log("📅 DEBUG - Fecha y hora de vuelta recibida:", fechaHoraVuelta);
    }

    // Convertir fecha y hora de ida a Date
    const fechaHoraIdaDate = new Date(fechaHoraIda);
    console.log("📅 DEBUG - Fecha y hora de ida convertida:", fechaHoraIdaDate.toISOString());

    // Obtener fecha y hora actual
    const ahora = new Date();
    console.log("📅 DEBUG - Fecha y hora actual:", ahora.toISOString());

    // Comparar las fechas
    if (fechaHoraIdaDate <= ahora) {
      console.log("❌ DEBUG - La fecha y hora de ida ya pasó");
      return handleErrorClient(res, 400, "La fecha y hora de ida no puede ser anterior o igual a la actual");
    }

    if (viajeIdaYVuelta && fechaHoraVuelta) {
      const fechaHoraVueltaDate = new Date(fechaHoraVuelta);
      console.log("📅 DEBUG - Fecha y hora de vuelta convertida:", fechaHoraVueltaDate.toISOString());

      if (fechaHoraVueltaDate <= fechaHoraIdaDate) {
        console.log("❌ DEBUG - La fecha y hora de vuelta es anterior o igual a la de ida");
        return handleErrorClient(res, 400, "La fecha y hora de vuelta no puede ser anterior o igual a la de ida");
      }
    }

    console.log("✅ DEBUG - Fechas y horas válidas");

    // Crear el viaje de ida
    const viajeIda = new Viaje({
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
      fecha_ida: new Date(fechaHoraIda),
      hora_ida: new Date(fechaHoraIda).toTimeString().substring(0, 5), // Extraer solo HH:mm
      fecha_vuelta: null, // Los viajes separados no tienen vuelta
      hora_vuelta: null,
      viaje_ida_vuelta: false, // Marcar como viaje simple
      max_pasajeros: maxPasajeros,
      solo_mujeres: soloMujeres,
      flexibilidad_salida: flexibilidadSalida,
      precio: precio,
      plazas_disponibles: plazasDisponibles,
      comentarios: comentarios,
      vehiculo_patente: vehiculoPatente
    });

    await viajeIda.save();

    // Crear chat grupal para el viaje de ida
    try {
      await crearChatGrupal(viajeIda._id.toString(), req.user.rut);
      console.log(`✅ Chat grupal creado para viaje de ida ${viajeIda._id}`);
      
      // Notificar al conductor que se creó el chat grupal
      notificarChatGrupalCreado(viajeIda._id.toString(), req.user.rut);
    } catch (chatError) {
      console.error(`⚠️ Error al crear chat grupal para viaje de ida ${viajeIda._id}:`, chatError.message);
      // No fallar la creación del viaje si falla el chat
    }

    let viajeVuelta = null;

    // Si es un viaje de ida y vuelta, crear el viaje de vuelta
    if (viajeIdaYVuelta && fechaHoraVuelta) {
      console.log("🔄 DEBUG - Creando viaje de vuelta");
      
      viajeVuelta = new Viaje({
        usuario_rut: req.user.rut,
        origen: {
          nombre: destino.displayName, // El origen de vuelta es el destino de ida
          ubicacion: {
            type: 'Point',
            coordinates: [destino.lon, destino.lat]
          }
        },
        destino: {
          nombre: origen.displayName, // El destino de vuelta es el origen de ida
          ubicacion: {
            type: 'Point',
            coordinates: [origen.lon, origen.lat]
          }
        },
        fecha_ida: new Date(fechaHoraVuelta),
        hora_ida: new Date(fechaHoraVuelta).toTimeString().substring(0, 5),
        fecha_vuelta: null, // Los viajes separados no tienen vuelta
        hora_vuelta: null,
        viaje_ida_vuelta: false, // Marcar como viaje simple
        max_pasajeros: maxPasajeros,
        solo_mujeres: soloMujeres,
        flexibilidad_salida: flexibilidadSalida,
        precio: precio,
        plazas_disponibles: plazasDisponibles,
        comentarios: comentarios ? `${comentarios} (Viaje de vuelta)` : "Viaje de vuelta",
        vehiculo_patente: vehiculoPatente
      });

      await viajeVuelta.save();

      // Crear chat grupal para el viaje de vuelta
      try {
        await crearChatGrupal(viajeVuelta._id.toString(), req.user.rut);
        console.log(`✅ Chat grupal creado para viaje de vuelta ${viajeVuelta._id}`);
        
        // Notificar al conductor que se creó el chat grupal
        notificarChatGrupalCreado(viajeVuelta._id.toString(), req.user.rut);
      } catch (chatError) {
        console.error(`⚠️ Error al crear chat grupal para viaje de vuelta ${viajeVuelta._id}:`, chatError.message);
        // No fallar la creación del viaje si falla el chat
      }
    }

    // Obtener datos completos para la respuesta
    const viajeIdaCompleto = await obtenerViajeConDatos(viajeIda._id);
    
    let respuestaData = {
      viaje_ida: viajeIdaCompleto
    };

    if (viajeVuelta) {
      const viajeVueltaCompleto = await obtenerViajeConDatos(viajeVuelta._id);
      respuestaData.viaje_vuelta = viajeVueltaCompleto;
    }

    const mensaje = viajeVuelta 
      ? "Viajes de ida y vuelta creados exitosamente" 
      : "Viaje creado exitosamente";

    handleSuccess(res, 201, mensaje, respuestaData);

  } catch (error) {
    console.error("Error al crear viaje:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Buscar viajes por proximidad (radio de X metros, modificar en la variable radio en kms.)
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
    }

    // Convertir radio de kilómetros a metros (500 metros = 0.5 km)
    const radioEnMetros = parseFloat(radio) * 1000;

    console.log('🔍 Parámetros de búsqueda:');
    console.log('Origen:', { lat: origenLat, lng: origenLng });
    console.log('Destino:', { lat: destinoLat, lng: destinoLng });
    console.log('Fecha:', fechaViaje);
    console.log('Radio (metros):', radioEnMetros);

    // CORREGIDO: Filtro de fecha - usar la fecha exacta proporcionada
    const fechaBuscada = new Date(fechaViaje + 'T00:00:00.000Z'); // Agregar hora UTC para evitar conversiones
    const fechaInicio = new Date(fechaBuscada);
    fechaInicio.setUTCHours(0, 0, 0, 0);
    const fechaFin = new Date(fechaBuscada);
    fechaFin.setUTCHours(23, 59, 59, 999);

    console.log('Filtro de fecha corregido:', { 
      fechaOriginal: fechaViaje,
      fechaBuscada: fechaBuscada.toISOString(),
      inicio: fechaInicio.toISOString(), 
      fin: fechaFin.toISOString() 
    });

    // Primero verificar si hay viajes activos en la fecha
    const viajesEnFecha = await Viaje.find({
      estado: 'activo',
      fecha_ida: { $gte: fechaInicio, $lte: fechaFin },
      plazas_disponibles: { $gte: parseInt(pasajeros) }
    }).select('_id origen.ubicacion.coordinates destino.ubicacion.coordinates fecha_ida plazas_disponibles');

    console.log('Viajes activos en la fecha:', viajesEnFecha.length);
    
    // Debug: mostrar todos los viajes para verificar
    const todosLosViajes = await Viaje.find({ estado: 'activo' })
      .select('_id fecha_ida plazas_disponibles origen.ubicacion.coordinates destino.ubicacion.coordinates')
      .sort({ fecha_ida: 1 });
    
    console.log('📋 Todos los viajes activos en DB:', todosLosViajes.map(v => ({
      id: v._id,
      fecha: v.fecha_ida.toISOString(),
      plazas: v.plazas_disponibles,
      origen_coords: v.origen?.ubicacion?.coordinates,
      destino_coords: v.destino?.ubicacion?.coordinates
    })));
    if (viajesEnFecha.length > 0) {
      console.log('Ejemplos de viajes en fecha:', viajesEnFecha.slice(0, 2).map(v => ({
        id: v._id,
        origen: v.origen?.ubicacion?.coordinates,
        destino: v.destino?.ubicacion?.coordinates,
        fecha: v.fecha_ida,
        plazas: v.plazas_disponibles
      })));
      
      // Calcular distancia manual para verificar - COORDENADAS CORREGIDAS
      const viajeEjemplo = viajesEnFecha[0];
      if (viajeEjemplo.origen?.ubicacion?.coordinates) {
        // En MongoDB: coordinates = [longitud, latitud]
        const viajeOrigenLng = viajeEjemplo.origen.ubicacion.coordinates[0]; // longitud
        const viajeOrigenLat = viajeEjemplo.origen.ubicacion.coordinates[1]; // latitud
        
        console.log('🗺️ Comparando coordenadas:');
        console.log('Búsqueda - Origen:', { lat: parseFloat(origenLat), lng: parseFloat(origenLng) });
        console.log('Viaje DB - Origen:', { lat: viajeOrigenLat, lng: viajeOrigenLng });
        
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
    }

    try {
      // Búsqueda con agregación para filtrar por proximidad de origen Y destino
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
          // CORREGIDO: origenLng es longitud [0], origenLat es latitud [1]
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
          // CORREGIDO: destinoLng es longitud [0], destinoLat es latitud [1]
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

    // Finalizar chat grupal cuando se cancela el viaje
    try {
      await finalizarChatGrupal(viajeId);
      console.log(`✅ Chat grupal finalizado para viaje cancelado ${viajeId}`);
      
      // Notificar a todos que el chat grupal fue finalizado por cancelación
      notificarChatGrupalFinalizado(viajeId, "cancelado");
    } catch (chatError) {
      console.error(`⚠️ Error al finalizar chat grupal:`, chatError.message);
      // No fallar la cancelación si falla el chat
    }

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

    // Finalizar chat grupal
    try {
      await finalizarChatGrupal(viajeId);
      console.log(`✅ Chat grupal finalizado para viaje eliminado ${viajeId}`);
      
      // Notificar a todos que el chat grupal fue finalizado por eliminación
      notificarChatGrupalFinalizado(viajeId, "eliminado");
    } catch (chatError) {
      console.error(`⚠️ Error al finalizar chat grupal:`, chatError.message);
      // No fallar la eliminación si falla el chat
    }

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

    // Agregar pasajero al chat grupal
    try {
      const participantes = await agregarParticipante(viajeId, usuarioRut);
      console.log(`✅ Pasajero ${usuarioRut} agregado al chat grupal del viaje ${viajeId}`);
      
      // Notificar a todos sobre el nuevo participante
      notificarParticipanteAgregado(viajeId, usuarioRut, participantes);
    } catch (chatError) {
      console.error(`⚠️ Error al agregar pasajero al chat grupal:`, chatError.message);
      // No fallar la confirmación si falla el chat
    }

    handleSuccess(res, 200, "Pasajero confirmado exitosamente", {
      usuarioRut: usuarioRut,
      estado: 'confirmado'
    });

  } catch (error) {
    console.error("Error al confirmar pasajero:", error);
    handleErrorServer(res, "Error interno del servidor");
  }
}

/**
 * Cambiar el estado de un viaje (solo el conductor)
 */
export async function cambiarEstadoViaje(req, res) {
  try {
    const { viajeId } = req.params;
    const { nuevoEstado } = req.body;
    const conductorRut = req.user.rut;

    // Estados válidos
    const estadosValidos = ['activo', 'en_curso', 'completado', 'cancelado'];
    if (!estadosValidos.includes(nuevoEstado)) {
      return handleErrorServer(res, 400, "Estado no válido");
    }

    // Buscar el viaje
    const viaje = await Viaje.findById(viajeId);
    if (!viaje) {
      return handleErrorServer(res, 404, "Viaje no encontrado");
    }

    // Verificar que el usuario autenticado es el conductor del viaje
    if (viaje.usuario_rut !== conductorRut) {
      return handleErrorServer(res, 403, "Solo el conductor puede cambiar el estado del viaje");
    }

    // Validar transiciones de estado
    const estadoActual = viaje.estado;
    
    // Lógica de transiciones válidas
    const transicionesValidas = {
      'activo': ['en_curso', 'cancelado'],
      'en_curso': ['completado', 'cancelado'],
      'completado': [], // Estado final
      'cancelado': [] // Estado final
    };

    if (!transicionesValidas[estadoActual]?.includes(nuevoEstado)) {
      return handleErrorServer(res, 400, `No se puede cambiar de "${estadoActual}" a "${nuevoEstado}"`);
    }

    // Actualizar el estado
    viaje.estado = nuevoEstado;
    viaje.fecha_actualizacion = new Date();
    
    // Si se completa el viaje, marcar fecha de finalización
    if (nuevoEstado === 'completado') {
      viaje.fecha_finalizacion = new Date();
    }

    await viaje.save();

    // Finalizar chat grupal cuando se completa o cancela el viaje
    if (nuevoEstado === 'completado' || nuevoEstado === 'cancelado') {
      try {
        await finalizarChatGrupal(viajeId);
        console.log(`✅ Chat grupal finalizado para viaje ${nuevoEstado} ${viajeId}`);
        
        // Notificar a todos que el chat grupal fue finalizado
        notificarChatGrupalFinalizado(viajeId, nuevoEstado);
      } catch (chatError) {
        console.error(`⚠️ Error al finalizar chat grupal:`, chatError.message);
        // No fallar el cambio de estado si falla el chat
      }
    }

    let mensaje = '';
    switch (nuevoEstado) {
      case 'en_curso':
        mensaje = 'Viaje iniciado exitosamente';
        break;
      case 'completado':
        mensaje = 'Viaje completado exitosamente';
        break;
      case 'cancelado':
        mensaje = 'Viaje cancelado';
        break;
      default:
        mensaje = 'Estado del viaje actualizado';
    }

    handleSuccess(res, 200, mensaje, {
      viajeId: viaje._id,
      estadoAnterior: estadoActual,
      estadoNuevo: nuevoEstado,
      fechaActualizacion: viaje.fecha_actualizacion
    });

  } catch (error) {
    console.error("Error al cambiar estado del viaje:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Unirse a viaje - crea una solicitud de notificación para unirse al viaje
 */
export async function unirseAViaje(req, res) {
  try {
    const { viajeId } = req.params;
    const userRut = req.user.rut;

    console.log(`🚪 Solicitando unirse al viaje ${viajeId} por usuario ${userRut}`);

    // Buscar el viaje en MongoDB
    const viaje = await Viaje.findById(viajeId);
    if (!viaje) {
      console.log(`❌ Viaje ${viajeId} no encontrado`);
      return handleErrorServer(res, 404, "Viaje no encontrado");
    }

    console.log(`📋 Viaje encontrado. Conductor: ${viaje.usuario_rut}`);

    // Verificar que el usuario no es el conductor
    if (viaje.usuario_rut === userRut) {
      console.log(`❌ Usuario ${userRut} es el conductor, no puede unirse a su propio viaje`);
      return handleErrorServer(res, 400, "No puedes unirte a tu propio viaje");
    }

    // Verificar que el usuario no está ya en el viaje
    const yaEsPasajero = viaje.pasajeros.some(p => p.usuario_rut === userRut);
    if (yaEsPasajero) {
      console.log(`❌ Usuario ${userRut} ya está en este viaje`);
      return handleErrorServer(res, 400, "Ya estás registrado en este viaje");
    }

    // Verificar que hay espacio disponible
    if (viaje.pasajeros.length >= viaje.maxPasajeros) {
      console.log(`❌ Viaje ${viajeId} está lleno`);
      return handleErrorServer(res, 400, "El viaje está completo");
    }

    // Verificar que el viaje esté en estado apropiado
    if (!['activo', 'confirmado'].includes(viaje.estado)) {
      console.log(`❌ Viaje ${viajeId} no está disponible para unirse (estado: ${viaje.estado})`);
      return handleErrorServer(res, 400, "Este viaje no está disponible para nuevos pasajeros");
    }

    // Crear la solicitud de notificación
    const { crearSolicitudViaje } = await import('../services/notificacion.service.js');
    
    await crearSolicitudViaje({
      conductorRut: viaje.usuario_rut,
      pasajeroRut: userRut,
      viajeId: viajeId,
      mensaje: `Solicitud para unirse al viaje de ${viaje.origen} a ${viaje.destino}`
    });

    console.log(`✅ Solicitud de viaje creada exitosamente para ${userRut} → ${viaje.usuario_rut}`);

    handleSuccess(res, 200, "Solicitud enviada al conductor. Espera su respuesta.", {
      viajeId: viaje._id,
      estado: 'pendiente',
      mensaje: 'Tu solicitud ha sido enviada al conductor'
    });

  } catch (error) {
    console.error("Error al solicitar unirse al viaje:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Abandonar viaje - permite a un pasajero salir del viaje
 */
export async function abandonarViaje(req, res) {
  try {
    const { viajeId } = req.params;
    const userRut = req.user.rut;

    console.log(`🚪 Intentando abandonar viaje ${viajeId} por usuario ${userRut}`);

    // Buscar el viaje en MongoDB
    const viaje = await Viaje.findById(viajeId);
    if (!viaje) {
      console.log(`❌ Viaje ${viajeId} no encontrado`);
      return handleErrorServer(res, 404, "Viaje no encontrado");
    }

    console.log(`📋 Viaje encontrado. Conductor: ${viaje.usuario_rut}`);
    console.log(`👥 Pasajeros en el viaje (${viaje.pasajeros.length}):`);
    viaje.pasajeros.forEach((p, index) => {
      console.log(`   ${index}: RUT="${p.usuario_rut}" Estado="${p.estado}"`);
    });

    // Verificar que el usuario no es el conductor
    if (viaje.usuario_rut === userRut) {
      console.log(`❌ Usuario ${userRut} es el conductor, no puede abandonar`);
      return handleErrorServer(res, 400, "El conductor no puede abandonar su propio viaje. Debe cancelarlo desde eliminar viaje.");
    }

    // Verificar que el usuario está realmente en el viaje como pasajero
    const pasajeroIndex = viaje.pasajeros.findIndex(p => p.usuario_rut === userRut);
    console.log(`🔍 Buscando pasajero con RUT "${userRut}". Índice encontrado: ${pasajeroIndex}`);
    
    if (pasajeroIndex === -1) {
      console.log(`❌ Usuario ${userRut} no está registrado en este viaje`);
      return handleErrorServer(res, 400, "No estás registrado en este viaje");
    }

    const pasajeroAEliminar = viaje.pasajeros[pasajeroIndex];
    console.log(`🗑️ Eliminando pasajero: RUT="${pasajeroAEliminar.usuario_rut}" Estado="${pasajeroAEliminar.estado}"`);

    // Remover al usuario de la lista de pasajeros
    viaje.pasajeros.splice(pasajeroIndex, 1);
    
    // Actualizar fecha de modificación
    viaje.fecha_actualizacion = new Date();

    // Guardar los cambios
    await viaje.save();

    // Eliminar del chat grupal
    try {
      const participantes = await eliminarParticipante(viajeId, userRut);
      console.log(`✅ Pasajero ${userRut} eliminado del chat grupal del viaje ${viajeId}`);
      
      // Notificar a todos sobre la eliminación del participante
      notificarParticipanteEliminado(viajeId, userRut, participantes);
    } catch (chatError) {
      console.error(`⚠️ Error al eliminar pasajero del chat grupal:`, chatError.message);
      // No fallar el abandono si falla el chat
    }

    console.log(`✅ Usuario ${userRut} abandonó el viaje ${viajeId} exitosamente`);
    console.log(`📊 Pasajeros restantes: ${viaje.pasajeros.length}/${viaje.maxPasajeros}`);

    handleSuccess(res, 200, "Has abandonado el viaje exitosamente", {
      viajeId: viaje._id,
      pasajerosRestantes: viaje.pasajeros.length,
      plazasDisponibles: viaje.maxPasajeros - viaje.pasajeros.length
    });

  } catch (error) {
    console.error("Error al abandonar viaje:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}