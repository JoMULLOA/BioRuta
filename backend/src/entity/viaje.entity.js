"use strict";
import mongoose from "mongoose";

const viajeSchema = new mongoose.Schema({
  _id: { 
    type: mongoose.Schema.Types.ObjectId, 
    auto: true 
  },
  
  // REFERENCIA AL USUARIO (PostgreSQL)
  usuario_rut: { 
    type: String, 
    required: true,
    ref: 'User' // Referencia conceptual, pero el rut está en PostgreSQL
  },
  
  // UBICACIONES CON ÍNDICES GEOESPACIALES
  origen: {
    nombre: { 
      type: String, 
      required: true, 
      maxLength: 500 
    },
    ubicacion: {
      type: { 
        type: String, 
        enum: ['Point'], 
        default: 'Point' 
      },
      coordinates: { 
        type: [Number], 
        required: true 
      } // [longitud, latitud]
    }
  },
  
  destino: {
    nombre: { 
      type: String, 
      required: true, 
      maxLength: 500 
    },
    ubicacion: {
      type: { 
        type: String, 
        enum: ['Point'], 
        default: 'Point' 
      },
      coordinates: { 
        type: [Number], 
        required: true 
      } // [longitud, latitud]
    }
  },
  
  // FECHAS Y HORARIOS
  fecha_ida: { 
    type: Date, 
    required: true 
  },
  fecha_vuelta: { 
    type: Date, 
    default: null 
  },
  viaje_ida_vuelta: { 
    type: Boolean, 
    default: false 
  },
  
  // CONFIGURACIÓN DEL VIAJE
  max_pasajeros: { 
    type: Number, 
    required: true, 
    min: 1, 
    max: 8, 
    default: 3 
  },
  solo_mujeres: { 
    type: Boolean, 
    default: false 
  },
  flexibilidad_salida: { 
    type: String, 
    enum: ['Puntual', '± 5 minutos', '± 10 minutos', '± 15 minutos'], 
    default: 'Puntual' 
  },
  
  // FINALIZACIÓN
  precio: { 
    type: Number, 
    required: true, 
    min: 0 
  },
  kilometros_ruta: {
    type: Number,
    required: true,
    min: 0,
    default: 0
  },
  plazas_disponibles: { 
    type: Number, 
    required: true, 
    min: 0 
  },
  comentarios: { 
    type: String, 
    maxLength: 1000 
  },
  
  // DATOS DEL VEHÍCULO (para mostrar en mapa) - referencia a PostgreSQL
  vehiculo_patente: {
    type: String,
    required: true,
    ref: 'Vehiculo' // Referencia conceptual, pero la patente está en PostgreSQL
  },
  
  // PASAJEROS ACTUALES
  pasajeros: [{
    usuario_rut: { 
      type: String, 
      required: true 
    },
    estado: { 
      type: String, 
      enum: ['pendiente', 'confirmado', 'rechazado'], 
      default: 'pendiente' 
    },
    pasajeros_solicitados: {
      type: Number,
      default: 1,
      min: 1
    },
    mensaje: {
      type: String,
      maxLength: 500
    },
    fecha_solicitud: { 
      type: Date, 
      default: Date.now 
    }
  }],
  
  // METADATOS
  estado: { 
    type: String, 
    enum: ['activo', 'cancelado', 'completado', 'en_curso'], 
    default: 'activo' 
  },
  fecha_creacion: { 
    type: Date, 
    default: Date.now 
  },
  fecha_actualizacion: { 
    type: Date, 
    default: Date.now 
  },
  fecha_finalizacion: {
    type: Date,
    default: null
  }
}, {
  timestamps: { 
    createdAt: 'fecha_creacion', 
    updatedAt: 'fecha_actualizacion' 
  }
});

// ÍNDICES GEOESPACIALES PARA BÚSQUEDA POR PROXIMIDAD
viajeSchema.index({ "origen.ubicacion": "2dsphere" });
viajeSchema.index({ "destino.ubicacion": "2dsphere" });
viajeSchema.index({ "fecha_ida": 1 });
viajeSchema.index({ "estado": 1 });
viajeSchema.index({ "usuario_rut": 1 });
viajeSchema.index({ "vehiculo_patente": 1 });

// MIDDLEWARE PARA ACTUALIZAR fecha_actualizacion
viajeSchema.pre('save', function(next) {
  this.fecha_actualizacion = new Date();
  next();
});

const Viaje = mongoose.model('Viaje', viajeSchema);

export default Viaje;
