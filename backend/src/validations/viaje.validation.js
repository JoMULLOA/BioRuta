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
  
  fechaHoraIda: Joi.date().min('now').required().messages({
    'date.min': 'La fecha y hora de ida no puede ser anterior al momento actual'
  }),
  
  fechaHoraVuelta: Joi.date().min(Joi.ref('fechaHoraIda')).allow(null).messages({
    'date.min': 'La fecha y hora de vuelta no puede ser anterior a la fecha de ida'
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
  if (value.viajeIdaYVuelta && !value.fechaHoraVuelta) {
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
  radio: Joi.number().min(0.1).max(50).default(2.0), // 2.0 km = 2000 metros por defecto
  soloMujeres: Joi.string().valid('true', 'false').default('false') // Filtro de género
});

// Validación para unirse a viaje
export const unirseViajeValidation = Joi.object({
  pasajeros_solicitados: Joi.number().integer().min(1).max(8).default(1),
  mensaje: Joi.string().max(500).allow('')
});

// Validación para unirse a viaje con pago
export const unirseViajeConPagoValidation = Joi.object({
  pasajeros_solicitados: Joi.number().integer().min(1).max(8).default(1),
  mensaje: Joi.string().max(500).allow(''),
  metodo_pago: Joi.string().valid('saldo', 'tarjeta', 'efectivo').required().messages({
    'any.required': 'El método de pago es requerido',
    'any.only': 'El método de pago debe ser: saldo, tarjeta o efectivo'
  }),
  datos_pago: Joi.object().allow(null)
});

// Validación para obtener viajes del mapa
export const viajesMapaValidation = Joi.object({
  fecha_desde: Joi.date().allow(''),
  fecha_hasta: Joi.date().min(Joi.ref('fecha_desde')).allow('')
});

// Validación para búsqueda de viajes en radar
export const viajesRadarValidation = Joi.object({
  lat: Joi.number().min(-90).max(90).required().messages({
    'any.required': 'La latitud es requerida',
    'number.min': 'La latitud debe estar entre -90 y 90',
    'number.max': 'La latitud debe estar entre -90 y 90'
  }),
  lng: Joi.number().min(-180).max(180).required().messages({
    'any.required': 'La longitud es requerida', 
    'number.min': 'La longitud debe estar entre -180 y 180',
    'number.max': 'La longitud debe estar entre -180 y 180'
  }),
  radio: Joi.number().min(0.1).max(10).required().messages({
    'any.required': 'El radio de búsqueda es requerido',
    'number.min': 'El radio mínimo es 0.1 km (100 metros)',
    'number.max': 'El radio máximo es 10 km'
  }),
  fecha: Joi.string().pattern(/^\d{4}-\d{2}-\d{2}$/).optional().messages({
    'string.pattern.base': 'La fecha debe tener el formato YYYY-MM-DD'
  })
});

// Validación para iniciar viaje
export const iniciarViajeValidation = Joi.object({
  viajeId: Joi.string().required().messages({
    'any.required': 'El ID del viaje es requerido'
  })
});

// Validación para conflicto de horarios de usuario
export const validarConflictoHorarioValidation = Joi.object({
  fechaHoraIda: Joi.date().required(),
  fechaHoraVuelta: Joi.date().allow(null),
  usuarioId: Joi.string().required(),
  viajeExcluidoId: Joi.string().allow(null) // Para excluir un viaje específico en ediciones
});

// Validación para cambio automático de estado
export const cambioEstadoAutomaticoValidation = Joi.object({
  viajeId: Joi.string().required(),
  estadoAnterior: Joi.string().valid('activo', 'en_curso', 'completado', 'cancelado').required(),
  estadoNuevo: Joi.string().valid('activo', 'en_curso', 'completado', 'cancelado').required(),
  razon: Joi.string().max(255).required().messages({
    'any.required': 'Se debe especificar la razón del cambio de estado'
  })
});
