"use strict";
import Joi from "joi";

// Validación para crear viaje
export const viajeBodyValidation = Joi.object({
  ubicaciones: Joi.array()
    .items(
      Joi.object({
        displayName: Joi.string().min(5).max(500).required(),
        lat: Joi.number().min(-90).max(90).required(),
        lon: Joi.number().min(-180).max(180).required(),
        esOrigen: Joi.boolean().required()
      })
    )
    .length(2)
    .required()
    .messages({
      'array.length': 'Debe proporcionar exactamente 2 ubicaciones: origen y destino'
    }),
  
  fechaIda: Joi.date().min('now').required().messages({
    'date.min': 'La fecha de ida no puede ser anterior a hoy'
  }),
  
  horaIda: Joi.string()
    .pattern(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/)
    .required()
    .messages({
      'string.pattern.base': 'La hora de ida debe tener formato HH:MM'
    }),
  
  fechaVuelta: Joi.date().min(Joi.ref('fechaIda')).allow(null),
  
  horaVuelta: Joi.string()
    .pattern(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/)
    .allow(null)
    .messages({
      'string.pattern.base': 'La hora de vuelta debe tener formato HH:MM'
    }),
  
  viajeIdaYVuelta: Joi.boolean().default(false),
  
  maxPasajeros: Joi.number().integer().min(1).max(8).required(),
  
  soloMujeres: Joi.boolean().default(false),
  
  flexibilidadSalida: Joi.string()
    .valid('Puntual', '± 5 minutos', '± 10 minutos', '± 15 minutos')
    .default('Puntual'),
  
  precio: Joi.number().min(0).required(),
  
  plazasDisponibles: Joi.number().integer().min(1).max(Joi.ref('maxPasajeros')).required(),
  
  comentarios: Joi.string().max(1000).allow(''),
  
  vehiculoPatente: Joi.string().required().messages({
    'any.required': 'Debe especificar el vehículo para el viaje'
  })
}).custom((value, helpers) => {
  // Validar que hay exactamente un origen y un destino
  const origen = value.ubicaciones.filter(u => u.esOrigen === true);
  const destino = value.ubicaciones.filter(u => u.esOrigen === false);
  
  if (origen.length !== 1) {
    return helpers.error('custom.origen');
  }
  
  if (destino.length !== 1) {
    return helpers.error('custom.destino');
  }
  
  // Validar que si es ida y vuelta, debe tener fecha y hora de vuelta
  if (value.viajeIdaYVuelta && (!value.fechaVuelta || !value.horaVuelta)) {
    return helpers.error('custom.idaVuelta');
  }
  
  return value;
}, 'Validación personalizada')
.messages({
  'custom.origen': 'Debe especificar exactamente un origen',
  'custom.destino': 'Debe especificar exactamente un destino',
  'custom.idaVuelta': 'Para viajes de ida y vuelta debe especificar fecha y hora de vuelta'
});

// Validación para búsqueda por proximidad
export const busquedaProximidadValidation = Joi.object({
  origenLat: Joi.number().min(-90).max(90).required(),
  origenLng: Joi.number().min(-180).max(180).required(),
  destinoLat: Joi.number().min(-90).max(90).required(),
  destinoLng: Joi.number().min(-180).max(180).required(),
  fechaViaje: Joi.string().required(),
  pasajeros: Joi.number().integer().min(1).max(8).default(1),
  radio: Joi.number().min(0.1).max(50).default(2.0) // 2.0 km = 2000 metros por defecto
});

// Validación para unirse a viaje
export const unirseViajeValidation = Joi.object({
  pasajeros_solicitados: Joi.number().integer().min(1).max(8).default(1),
  mensaje: Joi.string().max(500).allow('')
});

// Validación para obtener viajes del mapa
export const viajesMapaValidation = Joi.object({
  fecha_desde: Joi.date().allow(''),
  fecha_hasta: Joi.date().min(Joi.ref('fecha_desde')).allow('')
});
