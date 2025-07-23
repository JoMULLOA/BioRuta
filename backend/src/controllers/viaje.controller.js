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
      fecha_vuelta: null, // Los viajes separados no tienen vuelta
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
        fecha_vuelta: null, // Los viajes separados no tienen vuelta
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
      radio = 2.0, // 2000 metros en kilómetros por defecto
      soloMujeres = 'false' // Filtro de género (string que convertiremos a boolean)
    } = req.query;

    // Validar parámetros requeridos
    if (!origenLat || !origenLng || !destinoLat || !destinoLng || !fechaViaje) {
      return handleErrorServer(res, 400, "Parámetros requeridos: origenLat, origenLng, destinoLat, destinoLng, fechaViaje");
    }

    // Obtener el género del usuario que está haciendo la consulta
    const usuarioConsultante = await userRepository.findOne({
      where: { rut: req.user.rut }
    });

    if (!usuarioConsultante) {
      return handleErrorServer(res, 404, "Usuario no encontrado");
    }

    // Convertir string a boolean
    const filtraSoloMujeres = soloMujeres === 'true';

    // Convertir radio de kilómetros a metros (500 metros = 0.5 km)
    const radioEnMetros = parseFloat(radio) * 1000;

    console.log('🔍 Parámetros de búsqueda:');
    console.log('Origen:', { lat: origenLat, lng: origenLng });
    console.log('Destino:', { lat: destinoLat, lng: destinoLng });
    console.log('Fecha:', fechaViaje);
    console.log('Radio (metros):', radioEnMetros);
    console.log('Solo mujeres:', filtraSoloMujeres);
    console.log('Género usuario:', usuarioConsultante.genero);

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
    let filtroBase = {
      estado: 'activo',
      fecha_ida: { $gte: fechaInicio, $lte: fechaFin },
      plazas_disponibles: { $gte: parseInt(pasajeros) }
    };

    // Aplicar filtro de género
    // Si filtraSoloMujeres es true, solo mostrar viajes marcados como solo_mujeres
    // Si filtraSoloMujeres es false, aplicar las reglas normales de género
    if (filtraSoloMujeres) {
      // Usuario quiere ver solo viajes de mujeres (solo si el usuario es mujer)
      if (usuarioConsultante.genero === 'femenino') {
        filtroBase.solo_mujeres = true;
      } else {
        // Usuario no es mujer pero pide filtro de solo mujeres - no mostrar nada
        return handleSuccess(res, 200, "No hay viajes disponibles (filtro solo mujeres aplicado a usuario no femenino)", {
          viajes: [],
          total: 0
        });
      }
    } else {
      // Búsqueda normal - aplicar reglas de visibilidad por género
      if (usuarioConsultante.genero !== 'femenino') {
        // Usuario no es mujer - excluir viajes solo para mujeres
        filtroBase.solo_mujeres = { $ne: true };
      }
      // Si usuario es mujer, ver todos los viajes (incluidos los de solo mujeres)
    }

    const viajesEnFecha = await Viaje.find(filtroBase)
      .select('_id origen.ubicacion.coordinates destino.ubicacion.coordinates fecha_ida plazas_disponibles solo_mujeres');

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
        $match: filtroBase // Usar el mismo filtro que incluye las reglas de género
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
          precio: 1,
          plazas_disponibles: 1,
          max_pasajeros: 1,
          pasajeros: 1,
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
          fecha_ida: 1
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
        });

        // Calcular plazas disponibles dinámicamente
        const pasajerosConfirmados = viaje.pasajeros?.filter(p => p.estado === 'confirmado') || [];
        const plazasDisponiblesActuales = viaje.max_pasajeros - pasajerosConfirmados.length;

        return {
          ...viaje,
          plazas_disponibles: plazasDisponiblesActuales, // Sobrescribir con cálculo dinámico
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

    // Obtener el género del usuario que está haciendo la consulta
    const usuarioConsultante = await userRepository.findOne({
      where: { rut: req.user.rut }
    });

    if (!usuarioConsultante) {
      return handleErrorServer(res, 404, "Usuario no encontrado");
    }

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

    // Filtrar viajes según el género del usuario
    // Si el usuario no es mujer, excluir viajes que sean solo para mujeres
    if (usuarioConsultante.genero !== 'femenino') {
      filtroFecha.solo_mujeres = { $ne: true };
    }
    // Si el usuario es mujer, mostrar todos los viajes (incluidos los de solo mujeres)

    const viajes = await Viaje.find(filtroFecha)
      .select({
        _id: 1,
        usuario_rut: 1,
        vehiculo_patente: 1,
        origen: 1,
        destino: 1,
        fecha_ida: 1,
        precio: 1,
        max_pasajeros: 1,
        pasajeros: 1,
        plazas_disponibles: 1,
        solo_mujeres: 1  // Incluir campo solo_mujeres para mostrar en el mapa
      })
      .sort({ fecha_ida: 1 });

    console.log(`📊 Encontrados ${viajes.length} viajes para el mapa`);

    // Enriquecer con datos de PostgreSQL para el mapa
    const marcadores = await Promise.all(
      viajes.map(async (viaje) => {
        const conductor = await userRepository.findOne({
          where: { rut: viaje.usuario_rut }
        });

        const vehiculo = await vehiculoRepository.findOne({
          where: { patente: viaje.vehiculo_patente }
        });

        // Calcular plazas disponibles dinámicamente
        const pasajerosConfirmados = viaje.pasajeros?.filter(p => p.estado === 'confirmado') || [];
        const plazasDisponiblesActuales = viaje.max_pasajeros - pasajerosConfirmados.length;

        console.log(`🔢 Viaje ${viaje._id}: max_pasajeros=${viaje.max_pasajeros}, pasajeros_confirmados=${pasajerosConfirmados.length}, plazas_disponibles=${plazasDisponiblesActuales}`);

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
            hora: viaje.fecha_ida.toTimeString().substring(0, 5), // Extraer hora de fecha_ida
            precio: viaje.precio,
            plazas_disponibles: plazasDisponiblesActuales, // Usar cálculo dinámico
            solo_mujeres: viaje.solo_mujeres, // Incluir información de solo mujeres
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

  // Calcular plazas disponibles dinámicamente
  const pasajerosConfirmados = viaje.pasajeros.filter(p => p.estado === 'confirmado');
  const plazasDisponiblesActuales = viaje.max_pasajeros - pasajerosConfirmados.length;

  return {
    ...viaje.toObject(),
    plazasDisponibles: plazasDisponiblesActuales, // Agregar cálculo dinámico
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

    console.log(`🎯 Confirmando pasajero ${usuarioRut} en viaje ${viajeId} por conductor ${conductorRut}`);

    // Buscar el viaje
    const viaje = await Viaje.findById(viajeId);

    if (!viaje) {
      return handleErrorServer(res, 404, "Viaje no encontrado");
    }

    // Verificar que el usuario autenticado es el conductor del viaje
    if (viaje.usuario_rut !== conductorRut) {
      return handleErrorServer(res, 403, "Solo el conductor puede confirmar pasajeros");
    }

    // Buscar el pasajero en la lista
    const pasajeroIndex = viaje.pasajeros.findIndex(p => p.usuario_rut === usuarioRut);

    if (pasajeroIndex === -1) {
      return handleErrorServer(res, 404, "Pasajero no encontrado en este viaje");
    }

    const pasajero = viaje.pasajeros[pasajeroIndex];

    if (pasajero.estado === 'confirmado') {
      return handleErrorServer(res, 400, "El pasajero ya está confirmado");
    }

    if (pasajero.estado === 'rechazado') {
      return handleErrorServer(res, 400, "No se puede confirmar un pasajero rechazado");
    }

    // Buscar la notificación de solicitud para obtener información de pago
    const { AppDataSource } = await import('../config/configDb.js');
    const { default: Notificacion } = await import('../entity/notificacion.entity.js');
    
    const notificacionRepository = AppDataSource.getRepository(Notificacion);
    
    console.log(`🔍 Buscando notificación de solicitud para pasajero: ${usuarioRut}, conductor: ${conductorRut}, viaje: ${viajeId}`);
    
    const solicitud = await notificacionRepository.findOne({
      where: {
        rutEmisor: usuarioRut,
        rutReceptor: conductorRut,
        tipo: 'solicitud_viaje',
        viajeId: viajeId
      }
    });

    console.log(`📄 Notificación encontrada:`, solicitud ? 'SÍ' : 'NO');
    if (solicitud && solicitud.datos) {
      console.log(`💰 Datos de la solicitud:`, JSON.stringify(solicitud.datos, null, 2));
    }

    // Procesar pago si hay información de pago en la solicitud
    let resultadoPago = null;
    if (solicitud && solicitud.datos && solicitud.datos.pago) {
      console.log(`💳 ¡INFORMACIÓN DE PAGO ENCONTRADA! Procesando pago para pasajero ${usuarioRut}: ${JSON.stringify(solicitud.datos.pago)}`);
      
      try {
        resultadoPago = await procesarPagoViaje({
          pasajeroRut: usuarioRut,
          conductorRut: conductorRut,
          viajeId: viajeId,
          informacionPago: solicitud.datos.pago
        });
        
        console.log(`✅ ¡PAGO PROCESADO EXITOSAMENTE!: ${JSON.stringify(resultadoPago)}`);
      } catch (pagoError) {
        console.error(`❌ ERROR AL PROCESAR PAGO:`, pagoError);
        return handleErrorServer(res, 400, `Error al procesar el pago: ${pagoError.message}`);
      }
    } else {
      console.log(`⚠️ NO SE ENCONTRÓ INFORMACIÓN DE PAGO en la solicitud`);
    }

    // Confirmar el pasajero solo si el pago fue exitoso (o no hay pago)
    viaje.pasajeros[pasajeroIndex].estado = 'confirmado';
    await viaje.save();

    // Marcar la notificación como leída
    if (solicitud) {
      solicitud.leida = true;
      await notificacionRepository.save(solicitud);
    }

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

    const response = {
      usuarioRut: usuarioRut,
      estado: 'confirmado'
    };

    if (resultadoPago) {
      response.pago = resultadoPago;
    }

    handleSuccess(res, 200, "Pasajero confirmado exitosamente", response);

  } catch (error) {
    console.error("Error al confirmar pasajero:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Procesar pago de un viaje cuando se confirma un pasajero
 */
async function procesarPagoViaje({ pasajeroRut, conductorRut, viajeId, informacionPago }) {
  try {
    const { getUserService, updateUserService } = await import('../services/user.service.js');
    const { crearTransaccionService } = await import('../services/transaccion.service.js');
    
    console.log(`💰 Iniciando procesamiento de pago: ${informacionPago.metodo} por $${informacionPago.monto}`);
    console.log(`👥 Pasajero: ${pasajeroRut}, Conductor: ${conductorRut}, Viaje: ${viajeId}`);

    if (informacionPago.metodo === 'saldo') {
      // Obtener datos del pasajero y conductor
      console.log(`📋 Obteniendo datos de usuarios...`);
      const [pasajeroData, pasajeroError] = await getUserService({ rut: pasajeroRut });
      const [conductorData, conductorError] = await getUserService({ rut: conductorRut });

      console.log(`👤 Datos pasajero:`, pasajeroData ? `Saldo: ${pasajeroData.saldo}` : `Error: ${pasajeroError}`);
      console.log(`👨‍💼 Datos conductor:`, conductorData ? `Saldo: ${conductorData.saldo}` : `Error: ${conductorError}`);

      if (pasajeroError || conductorError) {
        throw new Error(`Error al obtener datos de usuarios: ${pasajeroError || conductorError}`);
      }

      const saldoPasajero = parseFloat(pasajeroData.saldo || 0);
      const saldoConductor = parseFloat(conductorData.saldo || 0);
      const monto = parseFloat(informacionPago.monto);

      console.log(`💳 Saldos actuales - Pasajero: $${saldoPasajero}, Conductor: $${saldoConductor}, Monto: $${monto}`);

      // Verificar saldo suficiente
      if (saldoPasajero < monto) {
        throw new Error(`Saldo insuficiente. Disponible: $${saldoPasajero}, Requerido: $${monto}`);
      }

      // Realizar transferencia
      const nuevoSaldoPasajero = saldoPasajero - monto;
      const nuevoSaldoConductor = saldoConductor + monto;

      console.log(`🔄 Iniciando transferencia de saldos...`);
      console.log(`📉 Pasajero: $${saldoPasajero} → $${nuevoSaldoPasajero}`);
      console.log(`📈 Conductor: $${saldoConductor} → $${nuevoSaldoConductor}`);

      // Actualizar saldos
      console.log(`💾 Actualizando saldo del pasajero...`);
      const [resultPasajero, errorPasajero] = await updateUserService(
        { rut: pasajeroRut }, 
        { saldo: nuevoSaldoPasajero.toString() }
      );
      
      console.log(`💾 Actualizando saldo del conductor...`);
      const [resultConductor, errorConductor] = await updateUserService(
        { rut: conductorRut }, 
        { saldo: nuevoSaldoConductor.toString() }
      );

      console.log(`📊 Resultado actualización pasajero:`, errorPasajero ? `Error: ${errorPasajero}` : 'Exitoso');
      console.log(`📊 Resultado actualización conductor:`, errorConductor ? `Error: ${errorConductor}` : 'Exitoso');

      if (errorPasajero || errorConductor) {
        throw new Error(`Error al actualizar saldos: ${errorPasajero || errorConductor}`);
      }

      // Crear registros de transacciones en el historial
      const transaccionId = `${viajeId}_${Date.now()}`;
      
      console.log(`📄 Creando transacciones en el historial...`);
      
      // Transacción de pago para el pasajero (monto negativo)
      await crearTransaccionService({
        usuario_rut: pasajeroRut,
        tipo: 'pago',
        concepto: `Pago de viaje ${viajeId}`,
        monto: -monto,
        metodo_pago: 'saldo',
        estado: 'completado',
        viaje_id: viajeId,
        transaccion_id: transaccionId,
        datos_adicionales: {
          conductor_rut: conductorRut,
          saldo_anterior: saldoPasajero,
          saldo_nuevo: nuevoSaldoPasajero
        }
      });

      // Transacción de cobro para el conductor (monto positivo)
      await crearTransaccionService({
        usuario_rut: conductorRut,
        tipo: 'cobro',
        concepto: `Cobro de viaje ${viajeId}`,
        monto: monto,
        metodo_pago: 'saldo',
        estado: 'completado',
        viaje_id: viajeId,
        transaccion_id: transaccionId,
        datos_adicionales: {
          pasajero_rut: pasajeroRut,
          saldo_anterior: saldoConductor,
          saldo_nuevo: nuevoSaldoConductor
        }
      });

      console.log(`✅ Transferencia completada - Nuevos saldos: Pasajero: $${nuevoSaldoPasajero}, Conductor: $${nuevoSaldoConductor}`);

      return {
        metodo: 'saldo',
        monto: monto,
        estado: 'completado',
        transaccion_id: transaccionId,
        saldo_anterior_pasajero: saldoPasajero,
        saldo_nuevo_pasajero: nuevoSaldoPasajero,
        saldo_anterior_conductor: saldoConductor,
        saldo_nuevo_conductor: nuevoSaldoConductor
      };

    } else if (informacionPago.metodo === 'tarjeta') {
      // Para las tarjetas del sandbox, simular proceso exitoso
      console.log(`💳 Procesando pago con tarjeta: ${informacionPago.tarjeta?.numero || 'N/A'}`);
      
      // Actualizar saldo del conductor (el pasajero paga con tarjeta, conductor recibe en saldo)
      const [conductorData, conductorError] = await getUserService({ rut: conductorRut });
      if (conductorError) {
        throw new Error(`Error al obtener datos del conductor: ${conductorError}`);
      }

      const saldoConductorActual = parseFloat(conductorData.saldo || 0);
      const monto = parseFloat(informacionPago.monto);
      const nuevoSaldoConductor = saldoConductorActual + monto;

      const [, errorUpdate] = await updateUserService(
        { rut: conductorRut }, 
        { saldo: nuevoSaldoConductor.toString() }
      );

      if (errorUpdate) {
        throw new Error(`Error al actualizar saldo del conductor: ${errorUpdate}`);
      }

      // Crear registros de transacciones en el historial
      const transaccionId = `${viajeId}_${Date.now()}`;
      
      // Transacción de pago con tarjeta para el pasajero
      await crearTransaccionService({
        usuario_rut: pasajeroRut,
        tipo: 'pago',
        concepto: `Pago de viaje ${viajeId} con tarjeta`,
        monto: -monto,
        metodo_pago: 'tarjeta',
        estado: 'completado',
        viaje_id: viajeId,
        transaccion_id: transaccionId,
        datos_adicionales: {
          conductor_rut: conductorRut,
          tarjeta: informacionPago.tarjeta
        }
      });

      // Transacción de cobro para el conductor
      await crearTransaccionService({
        usuario_rut: conductorRut,
        tipo: 'cobro',
        concepto: `Cobro de viaje ${viajeId} (pago con tarjeta)`,
        monto: monto,
        metodo_pago: 'tarjeta',
        estado: 'completado',
        viaje_id: viajeId,
        transaccion_id: transaccionId,
        datos_adicionales: {
          pasajero_rut: pasajeroRut,
          saldo_anterior: saldoConductorActual,
          saldo_nuevo: nuevoSaldoConductor
        }
      });

      console.log(`✅ Pago con tarjeta procesado - Conductor recibe: $${monto} (Saldo: $${saldoConductorActual} → $${nuevoSaldoConductor})`);

      return {
        metodo: 'tarjeta',
        monto: monto,
        estado: 'completado',
        transaccion_id: transaccionId,
        tarjeta: informacionPago.tarjeta,
        saldo_anterior_conductor: saldoConductorActual,
        saldo_nuevo_conductor: nuevoSaldoConductor
      };

    } else if (informacionPago.metodo === 'efectivo') {
      // Para efectivo, solo registrar la transacción pendiente
      console.log(`💵 Pago en efectivo registrado por $${informacionPago.monto}`);
      
      const transaccionId = `${viajeId}_${Date.now()}`;
      const monto = parseFloat(informacionPago.monto);

      // Crear transacción pendiente para el pasajero
      await crearTransaccionService({
        usuario_rut: pasajeroRut,
        tipo: 'pago',
        concepto: `Pago de viaje ${viajeId} en efectivo`,
        monto: -monto,
        metodo_pago: 'efectivo',
        estado: 'pendiente',
        viaje_id: viajeId,
        transaccion_id: transaccionId,
        datos_adicionales: {
          conductor_rut: conductorRut,
          nota: 'Pago a realizar en efectivo al conductor'
        }
      });

      // Crear transacción pendiente para el conductor
      await crearTransaccionService({
        usuario_rut: conductorRut,
        tipo: 'cobro',
        concepto: `Cobro de viaje ${viajeId} en efectivo`,
        monto: monto,
        metodo_pago: 'efectivo',
        estado: 'pendiente',
        viaje_id: viajeId,
        transaccion_id: transaccionId,
        datos_adicionales: {
          pasajero_rut: pasajeroRut,
          nota: 'Cobro a recibir en efectivo del pasajero'
        }
      });
      
      return {
        metodo: 'efectivo',
        monto: monto,
        estado: 'pendiente_efectivo',
        transaccion_id: transaccionId,
        nota: 'Pago a realizar en efectivo al conductor'
      };
    }

    throw new Error(`Método de pago no soportado: ${informacionPago.metodo}`);

  } catch (error) {
    console.error('❌ Error en procesarPagoViaje:', error.message);
    console.error('📋 Stack trace:', error.stack);
    throw error;
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
 * Unirse a viaje con información de pago - crea una solicitud con método de pago
 */
export async function unirseAViajeConPago(req, res) {
  try {
    const { viajeId } = req.params;
    const { metodo_pago, datos_pago, pasajeros_solicitados = 1, mensaje } = req.body;
    const userRut = req.user.rut;

    console.log(`💰 Solicitando unirse al viaje ${viajeId} con pago: ${metodo_pago} por usuario ${userRut}`);

    // Validar método de pago
    if (!['saldo', 'tarjeta', 'efectivo'].includes(metodo_pago)) {
      console.log(`❌ Método de pago inválido: ${metodo_pago}`);
      return handleErrorServer(res, 400, "Método de pago no válido");
    }

    // Buscar el viaje en MongoDB
    const viaje = await Viaje.findById(viajeId);
    if (!viaje) {
      console.log(`❌ Viaje ${viajeId} no encontrado`);
      return handleErrorServer(res, 404, "Viaje no encontrado");
    }

    console.log(`📋 Viaje encontrado. Conductor: ${viaje.usuario_rut}, Precio: ${viaje.precio}`);

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

    // Validaciones específicas por método de pago
    let informacionPago = {
      metodo: metodo_pago,
      monto: viaje.precio,
      estado: 'pendiente'
    };

    if (metodo_pago === 'saldo') {
      // Importar el servicio de usuario para verificar saldo
      const { getUserService } = await import('../services/user.service.js');
      const usuarioResult = await getUserService({ rut: userRut });
      
      if (usuarioResult[0] === null) {
        console.log(`❌ Usuario ${userRut} no encontrado:`, usuarioResult[1]);
        return handleErrorServer(res, 404, "Usuario no encontrado");
      }

      const usuario = usuarioResult[0];
      const saldoUsuario = parseFloat(usuario.saldo || 0);
      console.log(`💰 Saldo del usuario: ${saldoUsuario}, Precio del viaje: ${viaje.precio}`);
      
      if (saldoUsuario < viaje.precio) {
        console.log(`❌ Saldo insuficiente: ${saldoUsuario} < ${viaje.precio}`);
        return handleErrorServer(res, 400, "Saldo insuficiente para este viaje");
      }

      informacionPago.saldo_disponible = saldoUsuario;
    } else if (metodo_pago === 'tarjeta') {
      if (!datos_pago || !datos_pago.tarjeta) {
        return handleErrorServer(res, 400, "Información de tarjeta requerida");
      }

      const tarjetaData = datos_pago.tarjeta;
      
      informacionPago.tarjeta = {
        // Para mostrar en la notificación
        numero: tarjetaData.numero || '',
        tipo: tarjetaData.tipo || 'visa',
        titular: tarjetaData.nombreTitular || '',
        banco: tarjetaData.banco || 'Banco Sandbox',
        // Para el procesamiento de pago
        limiteCredito: tarjetaData.limiteCredito || 500000
      };
    }

    // Crear la solicitud de notificación con información de pago
    const { crearSolicitudViaje } = await import('../services/notificacion.service.js');
    
    await crearSolicitudViaje({
      conductorRut: viaje.usuario_rut,
      pasajeroRut: userRut,
      viajeId: viajeId,
      mensaje: mensaje || `Solicitud para unirse al viaje de ${viaje.origen} a ${viaje.destino}`,
      informacionPago: informacionPago
    });

    console.log(`✅ Solicitud de viaje con pago creada exitosamente para ${userRut} → ${viaje.usuario_rut}`);
    console.log(`💳 Método de pago: ${metodo_pago}, Monto: ${viaje.precio}`);

    handleSuccess(res, 200, "Solicitud con información de pago enviada al conductor. Espera su respuesta.", {
      viajeId: viaje._id,
      estado: 'pendiente',
      metodo_pago: metodo_pago,
      monto: viaje.precio,
      mensaje: 'Tu solicitud con información de pago ha sido enviada al conductor'
    });

  } catch (error) {
    console.error("Error al solicitar unirse al viaje con pago:", error);
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

/**
 * Buscar viajes en un radio específico para la funcionalidad de radar
 */
export async function obtenerViajesEnRadio(req, res) {
  try {
    console.log("🎯 Iniciando búsqueda de viajes en radar");
    console.log("📤 Body recibido:", req.body);

    const { lat, lng, radio, fecha } = req.body;

    // Validar parámetros requeridos
    if (!lat || !lng || !radio) {
      return handleErrorServer(res, 400, "Faltan parámetros requeridos: lat, lng, radio");
    }

    // Convertir a números
    const latitud = parseFloat(lat);
    const longitud = parseFloat(lng);
    const radioKm = parseFloat(radio);

    console.log(`📍 Buscando viajes en: lat=${latitud}, lng=${longitud}, radio=${radioKm}km`);

    // Debug: Verificar si hay viajes activos en general
    const totalViajesActivos = await Viaje.countDocuments({ estado: "activo" });
    console.log(`📊 Total de viajes activos en DB: ${totalViajesActivos}`);

    // Debug: Mostrar algunos viajes de ejemplo
    const viajesEjemplo = await Viaje.find({ estado: "activo" })
      .select('_id origen.nombre origen.ubicacion.coordinates fecha_ida plazas_disponibles')
      .limit(3);
    
    console.log(`📋 Ejemplos de viajes activos:`);
    viajesEjemplo.forEach((viaje, index) => {
      console.log(`  ${index + 1}. ID: ${viaje._id}`);
      console.log(`     Origen: ${viaje.origen.nombre}`);
      console.log(`     Coordenadas: [${viaje.origen.ubicacion.coordinates[0]}, ${viaje.origen.ubicacion.coordinates[1]}]`);
      console.log(`     Fecha: ${viaje.fecha_ida}`);
      console.log(`     Plazas: ${viaje.plazas_disponibles}`);
    });

    // Preparar filtro de fecha si se proporciona
    let filtroFecha = {};
    if (fecha) {
      // Crear rango de fecha para todo el día
      const fechaInicio = new Date(fecha + 'T00:00:00.000Z');
      const fechaFin = new Date(fecha + 'T23:59:59.999Z');
      
      filtroFecha = {
        fecha_ida: {
          $gte: fechaInicio,
          $lte: fechaFin
        }
      };
      console.log(`📅 Filtrando por fecha: ${fecha} (${fechaInicio.toISOString()} - ${fechaFin.toISOString()})`);
      
      // Debug: Verificar cuántos viajes hay en esa fecha
      const viajesEnFecha = await Viaje.countDocuments({
        estado: "activo",
        ...filtroFecha
      });
      console.log(`📅 Viajes activos en la fecha ${fecha}: ${viajesEnFecha}`);
    }

    console.log(`🔍 Ejecutando agregación $geoNear con:`);
    console.log(`   - Punto: [${longitud}, ${latitud}]`);
    console.log(`   - Radio máximo: ${radioKm * 1000} metros`);
    console.log(`   - Filtros: estado=activo${fecha ? `, fecha=${fecha}` : ''}`);

    // Buscar viajes usando agregación con geoNear

    // Buscar viajes usando agregación con geoNear
    const viajes = await Viaje.aggregate([
      {
        $geoNear: {
          near: {
            type: "Point",
            coordinates: [longitud, latitud]
          },
          distanceField: "distancia",
          maxDistance: radioKm * 1000, // Convertir km a metros
          spherical: true,
          key: "origen.ubicacion", // Especificar cuál campo usar para evitar ambigüedad
          query: {
            estado: "activo",
            ...filtroFecha
          }
        }
      },
      // COMENTADO: No excluir propios viajes para permitir ver todos los viajes en el radar
      // {
      //   $match: {
      //     // Asegurar que no sea el propio viaje del usuario si está autenticado
      //     usuario_rut: { $ne: req.user?.rut }
      //   }
      // },
      {
        $limit: 50 // Limitar resultados para mejor rendimiento
      }
    ]);

    console.log(`✅ Agregación $geoNear completada`);
    console.log(`📊 Viajes encontrados por agregación: ${viajes.length}`);
    
    if (viajes.length === 0) {
      console.log(`❌ No se encontraron viajes. Posibles causas:`);
      console.log(`   1. No hay viajes activos cerca del punto [${longitud}, ${latitud}]`);
      console.log(`   2. Problema con índice geoespacial en 'origen.ubicacion'`);
      console.log(`   3. Radio muy pequeño (${radioKm}km = ${radioKm * 1000}m)`);
      
      // Buscar el viaje más cercano sin límite de distancia
      console.log(`🔍 Buscando viaje más cercano sin límite de distancia...`);
      try {
        const viajesCercanos = await Viaje.aggregate([
          {
            $geoNear: {
              near: {
                type: "Point",
                coordinates: [longitud, latitud]
              },
              distanceField: "distancia",
              spherical: true,
              key: "origen.ubicacion",
              query: {
                estado: "activo",
                ...filtroFecha
              }
            }
          },
          { $limit: 3 }
        ]);
        
        console.log(`🎯 ${viajesCercanos.length} viajes más cercanos encontrados:`);
        viajesCercanos.forEach((viaje, index) => {
          console.log(`   ${index + 1}. Distancia: ${Math.round(viaje.distancia)}m`);
          console.log(`      Origen: ${viaje.origen.nombre}`);
          console.log(`      Coordenadas: [${viaje.origen.ubicacion.coordinates[0]}, ${viaje.origen.ubicacion.coordinates[1]}]`);
        });
        
      } catch (err) {
        console.error(`❌ Error buscando viajes cercanos:`, err.message);
      }
    } else {
      console.log(`✅ Primeros 3 viajes encontrados:`);
      viajes.slice(0, 3).forEach((viaje, index) => {
        console.log(`   ${index + 1}. ID: ${viaje._id}`);
        console.log(`      Distancia: ${Math.round(viaje.distancia)}m`);
        console.log(`      Origen: ${viaje.origen.nombre}`);
        console.log(`      Coordenadas: [${viaje.origen.ubicacion.coordinates[0]}, ${viaje.origen.ubicacion.coordinates[1]}]`);
      });
    }

    console.log(`✅ ${viajes.length} viajes encontrados en el radar`);

    // Enriquecer con datos de PostgreSQL
    const viajesEnriquecidos = await Promise.all(
      viajes.map(async (viaje) => {
        try {
          // Obtener datos del conductor usando usuario_rut
          const conductor = await userRepository.findOne({
            where: { rut: viaje.usuario_rut },
            select: ["rut", "nombreCompleto", "email"]
          });

          // Obtener datos del vehículo usando vehiculo_patente
          const vehiculo = await vehiculoRepository.findOne({
            where: { patente: viaje.vehiculo_patente },
            select: ["patente", "marca", "modelo", "año", "color", "tipo"]
          });

          return {
            id: viaje._id,
            origen: {
              nombre: viaje.origen.nombre,
              coordenadas: viaje.origen.ubicacion.coordinates
            },
            destino: {
              nombre: viaje.destino.nombre,
              coordenadas: viaje.destino.ubicacion.coordinates
            },
            fechaHoraIda: viaje.fecha_ida,
            maxPasajeros: viaje.max_pasajeros,
            precio: viaje.precio,
            plazasDisponibles: viaje.plazas_disponibles,
            distancia: Math.round(viaje.distancia), // Distancia en metros
            esPropio: viaje.usuario_rut === req.user?.rut, // Indicar si es del usuario actual
            conductor: conductor ? {
              rut: conductor.rut,
              nombre: conductor.nombreCompleto
            } : null,
            vehiculo: vehiculo ? {
              patente: vehiculo.patente,
              marca: vehiculo.marca,
              modelo: vehiculo.modelo,
              año: vehiculo.año,
              color: vehiculo.color,
              tipo: vehiculo.tipo
            } : null,
            coordenadas: {
              lat: viaje.origen.ubicacion.coordinates[1],
              lng: viaje.origen.ubicacion.coordinates[0]
            }
          };
        } catch (err) {
          console.error(`❌ Error enriqueciendo viaje ${viaje._id}:`, err);
          return null;
        }
      })
    );

    // Filtrar viajes nulos y devolver resultado
    const viajesValidos = viajesEnriquecidos.filter(viaje => viaje !== null);
    
    handleSuccess(res, 200, `${viajesValidos.length} viajes encontrados en el radar`, viajesValidos);

  } catch (error) {
    console.error("❌ Error en búsqueda de viajes por radar:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}

/**
 * Eliminar un pasajero de un viaje (solo el conductor puede hacer esto)
 */
export async function eliminarPasajero(req, res) {
  try {
    const { viajeId, usuarioRut } = req.params;
    const conductorRut = req.user.rut;

    console.log(`🗑️ Eliminando pasajero ${usuarioRut} del viaje ${viajeId} por conductor ${conductorRut}`);

    // Buscar el viaje
    const viaje = await Viaje.findById(viajeId);

    if (!viaje) {
      console.log(`❌ Viaje ${viajeId} no encontrado`);
      return handleErrorServer(res, 404, "Viaje no encontrado");
    }

    // Verificar que el usuario autenticado es el conductor del viaje
    if (viaje.usuario_rut !== conductorRut) {
      console.log(`❌ Usuario ${conductorRut} no es el conductor del viaje`);
      return handleErrorServer(res, 403, "Solo el conductor puede eliminar pasajeros");
    }

    console.log(`📋 Viaje encontrado. Conductor: ${viaje.usuario_rut}`);
    console.log(`👥 Pasajeros en el viaje (${viaje.pasajeros.length}):`);
    viaje.pasajeros.forEach((p, index) => {
      console.log(`   ${index}: RUT="${p.usuario_rut}" Estado="${p.estado}"`);
    });

    // Buscar el pasajero en la lista
    const pasajeroIndex = viaje.pasajeros.findIndex(p => p.usuario_rut === usuarioRut);
    console.log(`🔍 Buscando pasajero con RUT "${usuarioRut}". Índice encontrado: ${pasajeroIndex}`);

    if (pasajeroIndex === -1) {
      console.log(`❌ Pasajero ${usuarioRut} no encontrado en este viaje`);
      return handleErrorServer(res, 404, "Pasajero no encontrado en este viaje");
    }

    const pasajeroAEliminar = viaje.pasajeros[pasajeroIndex];
    console.log(`🗑️ Eliminando pasajero: RUT="${pasajeroAEliminar.usuario_rut}" Estado="${pasajeroAEliminar.estado}"`);

    // Verificar si necesitamos procesar un reembolso
    let reembolsoProcesado = false;
    if (pasajeroAEliminar.estado === 'confirmado') {
      try {
        // Buscar información de pago del pasajero
        const { AppDataSource } = await import('../config/configDb.js');
        const { default: Notificacion } = await import('../entity/notificacion.entity.js');
        
        const notificacionRepository = AppDataSource.getRepository(Notificacion);
        
        const solicitud = await notificacionRepository.findOne({
          where: {
            rutEmisor: usuarioRut,
            rutReceptor: conductorRut,
            tipo: 'solicitud_viaje',
            viajeId: viajeId
          }
        });

        if (solicitud && solicitud.datos && solicitud.datos.pago) {
          console.log(`💰 Procesando reembolso para pasajero ${usuarioRut}: ${JSON.stringify(solicitud.datos.pago)}`);
          
          // Aquí se implementaría la lógica de reembolso con MercadoPago
          // Por ahora, simular que el reembolso se procesa exitosamente
          reembolsoProcesado = true;
          console.log(`✅ Reembolso procesado exitosamente para ${usuarioRut}`);
        }
      } catch (reembolsoError) {
        console.error(`⚠️ Error procesando reembolso:`, reembolsoError.message);
        // Continuar con la eliminación aunque falle el reembolso
      }
    }

    // Remover al pasajero de la lista
    viaje.pasajeros.splice(pasajeroIndex, 1);
    
    // Actualizar fecha de modificación
    viaje.fecha_actualizacion = new Date();

    // Guardar los cambios
    await viaje.save();

    // Eliminar del chat grupal
    try {
      const participantes = await eliminarParticipante(viajeId, usuarioRut);
      console.log(`✅ Pasajero ${usuarioRut} eliminado del chat grupal del viaje ${viajeId}`);
      
      // Notificar a todos sobre la eliminación del participante
      notificarParticipanteEliminado(viajeId, usuarioRut, participantes);
    } catch (chatError) {
      console.error(`⚠️ Error al eliminar pasajero del chat grupal:`, chatError.message);
      // No fallar la eliminación si falla el chat
    }

    // Crear notificación para el pasajero eliminado
    try {
      const { crearNotificacion } = await import('../services/notificacion.service.js');
      
      await crearNotificacion({
        rutEmisor: conductorRut,
        rutReceptor: usuarioRut,
        tipo: 'pasajero_eliminado',
        titulo: 'Eliminado de viaje',
        mensaje: `Has sido eliminado del viaje por el conductor.${reembolsoProcesado ? ' Se ha procesado tu reembolso.' : ''}`,
        viajeId: viajeId,
        datos: {
          viajeId: viajeId,
          reembolsoProcesado: reembolsoProcesado
        }
      });
      
      console.log(`📧 Notificación de eliminación enviada a ${usuarioRut}`);
    } catch (notificacionError) {
      console.error(`⚠️ Error creando notificación:`, notificacionError.message);
      // No fallar la eliminación si falla la notificación
    }

    console.log(`✅ Pasajero ${usuarioRut} eliminado del viaje ${viajeId} exitosamente`);
    console.log(`📊 Pasajeros restantes: ${viaje.pasajeros.length}/${viaje.maxPasajeros}`);

    handleSuccess(res, 200, "Pasajero eliminado exitosamente", {
      viajeId: viaje._id,
      usuarioEliminado: usuarioRut,
      pasajerosRestantes: viaje.pasajeros.length,
      plazasDisponibles: viaje.maxPasajeros - viaje.pasajeros.length,
      reembolsoProcesado: reembolsoProcesado
    });

  } catch (error) {
    console.error("❌ Error al eliminar pasajero:", error);
    handleErrorServer(res, 500, "Error interno del servidor");
  }
}