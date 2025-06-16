# 📋 DOCUMENTACIÓN BACKEND - SISTEMA DE PUBLICACIÓN DE VIAJES

## 📝 RESUMEN DEL FLUJO
El sistema de publicación de viajes en la app BioRuta consta de 4 pasos principales que el usuario debe completar antes de publicar un viaje. Este documento detalla todas las variables, estructuras de datos y endpoints necesarios para implementar esto en Node.js.

---

## 🗂️ ESTRUCTURA DE DATOS

### 1. **Modelo Principal: VIAJE**
```sql
CREATE TABLE viajes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    usuario_id INT NOT NULL,
    
    -- PASO 1: UBICACIONES
    origen_nombre VARCHAR(500) NOT NULL,
    origen_latitud DECIMAL(10, 8) NOT NULL,
    origen_longitud DECIMAL(11, 8) NOT NULL,
    destino_nombre VARCHAR(500) NOT NULL,
    destino_latitud DECIMAL(10, 8) NOT NULL,
    destino_longitud DECIMAL(11, 8) NOT NULL,
    
    -- PASO 2: FECHAS Y HORARIOS
    fecha_ida DATE NOT NULL,
    hora_ida TIME NOT NULL,
    fecha_vuelta DATE NULL,
    hora_vuelta TIME NULL,
    viaje_ida_vuelta BOOLEAN DEFAULT FALSE,
    
    -- PASO 3: CONFIGURACIÓN DEL VIAJE
    max_pasajeros INT NOT NULL DEFAULT 3,
    solo_mujeres BOOLEAN DEFAULT FALSE,
    flexibilidad_salida ENUM('Puntual', '± 5 minutos', '± 10 minutos', '± 15 minutos') DEFAULT 'Puntual',
    
    -- PASO 4: FINALIZACIÓN
    precio DECIMAL(8, 2) NOT NULL,
    plazas_disponibles INT NOT NULL,
    comentarios TEXT NULL,
    
    -- METADATOS
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    estado ENUM('activo', 'cancelado', 'completado') DEFAULT 'activo',
    
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
);
```

### 2. **Índices Recomendados**
```sql
CREATE INDEX idx_viajes_origen ON viajes(origen_latitud, origen_longitud);
CREATE INDEX idx_viajes_destino ON viajes(destino_latitud, destino_longitud);
CREATE INDEX idx_viajes_fecha_ida ON viajes(fecha_ida);
CREATE INDEX idx_viajes_usuario ON viajes(usuario_id);
CREATE INDEX idx_viajes_estado ON viajes(estado);
```

---

## 🔄 ENDPOINTS NECESARIOS

### 1. **POST /api/viajes/crear**
**Descripción**: Crear un nuevo viaje con todos los datos del flujo de 4 pasos
**Body**:
```json
{
  "ubicaciones": [
    {
      "displayName": "Providencia, Santiago, Chile",
      "lat": -33.4372,
      "lon": -70.6506,
      "esOrigen": true
    },
    {
      "displayName": "Las Condes, Santiago, Chile", 
      "lat": -33.4126,
      "lon": -70.5698,
      "esOrigen": false
    }
  ],
  "fechaIda": "2025-06-15T00:00:00.000Z",
  "horaIda": "08:30",
  "fechaVuelta": "2025-06-15T00:00:00.000Z", // null si no es ida y vuelta
  "horaVuelta": "18:00", // null si no es ida y vuelta
  "viajeIdaYVuelta": false,
  "maxPasajeros": 3,
  "soloMujeres": false,
  "flexibilidadSalida": "± 5 minutos",
  "precio": 15.50,
  "plazasDisponibles": 3,
  "comentarios": "Viaje cómodo y seguro. Salida puntual."
}
```

### 2. **GET /api/viajes/buscar**
**Descripción**: Buscar viajes según criterios
**Query Parameters**:
```
?origen_lat=-33.4372&origen_lon=-70.6506&destino_lat=-33.4126&destino_lon=-70.5698&fecha=2025-06-15&pasajeros=2&radio=5
```

### 3. **GET /api/viajes/usuario/:id**
**Descripción**: Obtener viajes de un usuario específico

### 4. **PUT /api/viajes/:id**
**Descripción**: Actualizar un viaje existente

### 5. **DELETE /api/viajes/:id**
**Descripción**: Cancelar/eliminar un viaje

---

## 📤 FORMATO DE DATOS DEL FRONTEND

### **Objeto enviado desde el Flutter al crear viaje:**
```javascript
const datosViaje = {
  ubicaciones: [
    {
      displayName: "Providencia, Santiago, Chile",
      lat: -33.4372,
      lon: -70.6506,
      esOrigen: true
    },
    {
      displayName: "Las Condes, Santiago, Chile",
      lat: -33.4126,
      lon: -70.5698,
      esOrigen: false
    }
  ],
  fechaIda: "2025-06-15T00:00:00.000Z",
  horaIda: "8:30",
  fechaVuelta: null, // o fecha si es ida y vuelta
  horaVuelta: null, // o hora si es ida y vuelta
  viajeIdaYVuelta: false,
  maxPasajeros: 3,
  soloMujeres: false,
  flexibilidadSalida: "Puntual",
  precio: 15.50,
  plazasDisponibles: 3,
  comentarios: "Comentarios opcionales del conductor"
};
```

---

## 🛠️ IMPLEMENTACIÓN NODE.JS

### 1. **Controlador de Viajes (viaje.controller.js)**
```javascript
const crearViaje = async (req, res) => {
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
      comentarios
    } = req.body;

    // Validar que hay exactamente 2 ubicaciones (origen y destino)
    if (!ubicaciones || ubicaciones.length !== 2) {
      return res.status(400).json({
        error: 'Debe proporcionar exactamente 2 ubicaciones: origen y destino'
      });
    }

    const origen = ubicaciones.find(u => u.esOrigen === true);
    const destino = ubicaciones.find(u => u.esOrigen === false);

    if (!origen || !destino) {
      return res.status(400).json({
        error: 'Debe especificar claramente el origen y destino'
      });
    }

    // Crear el viaje en la base de datos
    const nuevoViaje = await Viaje.create({
      usuario_id: req.user.id, // Del middleware de autenticación
      origen_nombre: origen.displayName,
      origen_latitud: origen.lat,
      origen_longitud: origen.lon,
      destino_nombre: destino.displayName,
      destino_latitud: destino.lat,
      destino_longitud: destino.lon,
      fecha_ida: fechaIda,
      hora_ida: horaIda,
      fecha_vuelta: fechaVuelta,
      hora_vuelta: horaVuelta,
      viaje_ida_vuelta: viajeIdaYVuelta,
      max_pasajeros: maxPasajeros,
      solo_mujeres: soloMujeres,
      flexibilidad_salida: flexibilidadSalida,
      precio: precio,
      plazas_disponibles: plazasDisponibles,
      comentarios: comentarios
    });

    res.status(201).json({
      mensaje: 'Viaje creado exitosamente',
      viaje: nuevoViaje
    });

  } catch (error) {
    console.error('Error al crear viaje:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
};
```

### 2. **Modelo de Viaje (viaje.model.js)**
```javascript
const { DataTypes } = require('sequelize');

const ViajeModel = (sequelize) => {
  const Viaje = sequelize.define('Viaje', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    usuario_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'usuarios',
        key: 'id'
      }
    },
    // Ubicaciones
    origen_nombre: {
      type: DataTypes.STRING(500),
      allowNull: false
    },
    origen_latitud: {
      type: DataTypes.DECIMAL(10, 8),
      allowNull: false
    },
    origen_longitud: {
      type: DataTypes.DECIMAL(11, 8),
      allowNull: false
    },
    destino_nombre: {
      type: DataTypes.STRING(500),
      allowNull: false
    },
    destino_latitud: {
      type: DataTypes.DECIMAL(10, 8),
      allowNull: false
    },
    destino_longitud: {
      type: DataTypes.DECIMAL(11, 8),
      allowNull: false
    },
    // Fechas y horarios
    fecha_ida: {
      type: DataTypes.DATEONLY,
      allowNull: false
    },
    hora_ida: {
      type: DataTypes.TIME,
      allowNull: false
    },
    fecha_vuelta: {
      type: DataTypes.DATEONLY,
      allowNull: true
    },
    hora_vuelta: {
      type: DataTypes.TIME,
      allowNull: true
    },
    viaje_ida_vuelta: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    },
    // Configuración
    max_pasajeros: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 3
    },
    solo_mujeres: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    },
    flexibilidad_salida: {
      type: DataTypes.ENUM('Puntual', '± 5 minutos', '± 10 minutos', '± 15 minutos'),
      defaultValue: 'Puntual'
    },
    // Finalización
    precio: {
      type: DataTypes.DECIMAL(8, 2),
      allowNull: false
    },
    plazas_disponibles: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    comentarios: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    // Estado
    estado: {
      type: DataTypes.ENUM('activo', 'cancelado', 'completado'),
      defaultValue: 'activo'
    }
  }, {
    tableName: 'viajes',
    timestamps: true,
    createdAt: 'fecha_creacion',
    updatedAt: 'fecha_actualizacion'
  });

  return Viaje;
};

module.exports = ViajeModel;
```

### 3. **Validaciones (viaje.validation.js)**
```javascript
const { body, query } = require('express-validator');

const validarCrearViaje = [
  body('ubicaciones')
    .isArray({ min: 2, max: 2 })
    .withMessage('Debe proporcionar exactamente 2 ubicaciones'),
  
  body('ubicaciones.*.displayName')
    .trim()
    .isLength({ min: 5, max: 500 })
    .withMessage('El nombre de la ubicación debe tener entre 5 y 500 caracteres'),
  
  body('ubicaciones.*.lat')
    .isFloat({ min: -90, max: 90 })
    .withMessage('La latitud debe estar entre -90 y 90'),
  
  body('ubicaciones.*.lon')
    .isFloat({ min: -180, max: 180 })
    .withMessage('La longitud debe estar entre -180 y 180'),
  
  body('fechaIda')
    .isISO8601()
    .withMessage('La fecha de ida debe ser una fecha válida'),
  
  body('horaIda')
    .matches(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/)
    .withMessage('La hora de ida debe tener formato HH:MM'),
  
  body('maxPasajeros')
    .isInt({ min: 1, max: 8 })
    .withMessage('El número de pasajeros debe estar entre 1 y 8'),
  
  body('precio')
    .isFloat({ min: 0 })
    .withMessage('El precio debe ser un valor positivo'),
  
  body('flexibilidadSalida')
    .isIn(['Puntual', '± 5 minutos', '± 10 minutos', '± 15 minutos'])
    .withMessage('Flexibilidad de salida no válida')
];

module.exports = {
  validarCrearViaje
};
```

---

## 🔍 CONSULTAS ÚTILES

### 1. **Buscar viajes por proximidad geográfica**
```sql
SELECT *, 
  (6371 * acos(cos(radians(?)) * cos(radians(origen_latitud)) * 
  cos(radians(origen_longitud) - radians(?)) + 
  sin(radians(?)) * sin(radians(origen_latitud)))) AS distancia_origen,
  (6371 * acos(cos(radians(?)) * cos(radians(destino_latitud)) * 
  cos(radians(destino_longitud) - radians(?)) + 
  sin(radians(?)) * sin(radians(destino_latitud)))) AS distancia_destino
FROM viajes 
WHERE estado = 'activo' 
  AND fecha_ida >= CURDATE()
  AND plazas_disponibles >= ?
HAVING distancia_origen <= ? AND distancia_destino <= ?
ORDER BY fecha_ida ASC, hora_ida ASC;
```

### 2. **Obtener viajes de un usuario**
```sql
SELECT * FROM viajes 
WHERE usuario_id = ? 
ORDER BY fecha_creacion DESC;
```

### 3. **Viajes próximos a expirar**
```sql
SELECT * FROM viajes 
WHERE estado = 'activo' 
  AND fecha_ida = CURDATE() 
  AND hora_ida <= TIME(DATE_ADD(NOW(), INTERVAL 2 HOUR));
```

---

## 📊 CONSIDERACIONES TÉCNICAS

### **1. Cálculo de Distancias**
- Usar fórmula Haversine para calcular distancias entre coordenadas
- Radio de búsqueda recomendado: 5-10 km
- Considerar crear índices espaciales para optimizar consultas

### **2. Gestión de Estados**
- `activo`: Viaje disponible para reservas
- `cancelado`: Viaje cancelado por el conductor
- `completado`: Viaje realizado exitosamente

### **3. Notificaciones**
- Implementar notificaciones push cuando:
  - Se crea un viaje en la ruta del usuario
  - Un viaje del usuario recibe una reserva
  - Cambios en viajes reservados

### **4. Validaciones de Negocio**
- No permitir crear viajes en fechas pasadas
- Validar que origen y destino sean diferentes
- Controlar plazas disponibles vs máximo de pasajeros
- Verificar que el usuario tenga vehículo registrado

---

## 🚀 PRÓXIMOS PASOS

1. **Implementar reservas de viajes**
2. **Sistema de calificaciones**
3. **Chat entre conductor y pasajeros**
4. **Gestión de pagos**
5. **Historial de viajes**

---

# 🗄️ IMPLEMENTACIÓN MONGODB - BÚSQUEDA POR RADIO Y MAPA INTERACTIVO

## 🎯 OBJETIVOS
1. **Búsqueda por proximidad**: Radio de 500m para origen y destino
2. **Mapa interactivo**: Mostrar vehículos en puntos de viajes publicados
3. **Funcionalidad de clic**: Desplegar datos del viaje y opción de unirse

---

## 📊 ESQUEMA MONGODB

### 1. **Colección: viajes**
```javascript
// Schema para MongoDB con índices geoespaciales
const viajeSchema = new mongoose.Schema({
  _id: { type: mongoose.Schema.Types.ObjectId, auto: true },
  usuario_id: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Usuario', 
    required: true 
  },
  
  // UBICACIONES CON ÍNDICES GEOESPACIALES
  origen: {
    nombre: { type: String, required: true, maxLength: 500 },
    ubicacion: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], required: true } // [longitud, latitud]
    }
  },
  destino: {
    nombre: { type: String, required: true, maxLength: 500 },
    ubicacion: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], required: true } // [longitud, latitud]
    }
  },
  
  // FECHAS Y HORARIOS
  fecha_ida: { type: Date, required: true },
  hora_ida: { type: String, required: true }, // "HH:MM"
  fecha_vuelta: { type: Date, default: null },
  hora_vuelta: { type: String, default: null },
  viaje_ida_vuelta: { type: Boolean, default: false },
  
  // CONFIGURACIÓN DEL VIAJE
  max_pasajeros: { type: Number, required: true, min: 1, max: 8, default: 3 },
  solo_mujeres: { type: Boolean, default: false },
  flexibilidad_salida: { 
    type: String, 
    enum: ['Puntual', '± 5 minutos', '± 10 minutos', '± 15 minutos'], 
    default: 'Puntual' 
  },
  
  // FINALIZACIÓN
  precio: { type: Number, required: true, min: 0 },
  plazas_disponibles: { type: Number, required: true, min: 0 },
  comentarios: { type: String, maxLength: 1000 },
  
  // DATOS DEL VEHÍCULO (para mostrar en mapa)
  vehiculo: {
    tipo: { type: String, required: true }, // "Sedan", "SUV", "Hatchback", etc.
    color: { type: String, required: true },
    marca: { type: String, required: true },
    modelo: { type: String, required: true },
    patente: { type: String, required: true }
  },
  
  // PASAJEROS ACTUALES
  pasajeros: [{
    usuario_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Usuario' },
    estado: { type: String, enum: ['pendiente', 'confirmado', 'rechazado'], default: 'pendiente' },
    fecha_solicitud: { type: Date, default: Date.now }
  }],
  
  // METADATOS
  estado: { 
    type: String, 
    enum: ['activo', 'cancelado', 'completado', 'en_curso'], 
    default: 'activo' 
  },
  fecha_creacion: { type: Date, default: Date.now },
  fecha_actualizacion: { type: Date, default: Date.now }
}, {
  timestamps: { createdAt: 'fecha_creacion', updatedAt: 'fecha_actualizacion' }
});

// ÍNDICES GEOESPACIALES PARA BÚSQUEDA POR PROXIMIDAD
viajeSchema.index({ "origen.ubicacion": "2dsphere" });
viajeSchema.index({ "destino.ubicacion": "2dsphere" });
viajeSchema.index({ "fecha_ida": 1 });
viajeSchema.index({ "estado": 1 });
viajeSchema.index({ "usuario_id": 1 });

module.exports = mongoose.model('Viaje', viajeSchema);
```

---

## 🔍 CONTROLADORES CON BÚSQUEDA POR RADIO

### 1. **Crear Viaje con Datos del Vehículo**
```javascript
// controllers/viaje.controller.js
const Viaje = require('../models/viaje.model');
const Usuario = require('../models/usuario.model');

const crearViaje = async (req, res) => {
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
      vehiculo // Nuevo: datos del vehículo
    } = req.body;

    // Validar ubicaciones
    if (!ubicaciones || ubicaciones.length !== 2) {
      return res.status(400).json({
        error: 'Debe proporcionar exactamente 2 ubicaciones: origen y destino'
      });
    }

    const origen = ubicaciones.find(u => u.esOrigen === true);
    const destino = ubicaciones.find(u => u.esOrigen === false);

    // Crear el viaje
    const nuevoViaje = new Viaje({
      usuario_id: req.user.id,
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
      vehiculo: vehiculo
    });

    await nuevoViaje.save();
    await nuevoViaje.populate('usuario_id', 'nombre email telefono calificacion');

    res.status(201).json({
      mensaje: 'Viaje creado exitosamente',
      viaje: nuevoViaje
    });

  } catch (error) {
    console.error('Error al crear viaje:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
};
```

### 2. **Búsqueda con Radio de 500 Metros**
```javascript
const buscarViajesPorProximidad = async (req, res) => {
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
      return res.status(400).json({
        error: 'Parámetros requeridos: origen_lat, origen_lon, destino_lat, destino_lon, fecha'
      });
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
        $lookup: {
          from: 'usuarios',
          localField: 'usuario_id',
          foreignField: '_id',
          as: 'conductor'
        }
      },
      {
        $unwind: '$conductor'
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
          distancia_destino: { $lte: radioEnMetros }
        }
      },
      {
        $project: {
          _id: 1,
          origen: 1,
          destino: 1,
          fecha_ida: 1,
          hora_ida: 1,
          precio: 1,
          plazas_disponibles: 1,
          max_pasajeros: 1,
          vehiculo: 1,
          comentarios: 1,
          flexibilidad_salida: 1,
          solo_mujeres: 1,
          conductor: {
            _id: 1,
            nombre: 1,
            calificacion: 1,
            foto_perfil: 1
          },
          distancia_origen: { $round: ['$distancia_origen', 0] },
          distancia_destino: { $round: ['$distancia_destino', 0] }
        }
      },
      {
        $sort: { fecha_ida: 1, hora_ida: 1 }
      }
    ]);

    res.json({
      mensaje: `Se encontraron ${viajes.length} viajes disponibles`,
      viajes: viajes,
      criterios_busqueda: {
        radio_metros: radioEnMetros,
        fecha: fecha,
        pasajeros: pasajeros,
        origen: { lat: origen_lat, lon: origen_lon },
        destino: { lat: destino_lat, lon: destino_lon }
      }
    });

  } catch (error) {
    console.error('Error en búsqueda por proximidad:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
};
```

### 3. **Obtener Viajes para Mapa Interactivo**
```javascript
const obtenerViajesParaMapa = async (req, res) => {
  try {
    const {
      bounds, // Límites del mapa visible
      fecha_desde,
      fecha_hasta
    } = req.query;

    let filtroFecha = {};
    if (fecha_desde || fecha_hasta) {
      filtroFecha.fecha_ida = {};
      if (fecha_desde) filtroFecha.fecha_ida.$gte = new Date(fecha_desde);
      if (fecha_hasta) filtroFecha.fecha_ida.$lte = new Date(fecha_hasta);
    }

    const viajes = await Viaje.find({
      estado: 'activo',
      plazas_disponibles: { $gt: 0 },
      ...filtroFecha
    })
    .populate('usuario_id', 'nombre calificacion foto_perfil')
    .select({
      _id: 1,
      origen: 1,
      destino: 1,
      fecha_ida: 1,
      hora_ida: 1,
      precio: 1,
      plazas_disponibles: 1,
      vehiculo: 1,
      usuario_id: 1
    })
    .sort({ fecha_ida: 1 });

    // Formatear para el mapa
    const marcadores = viajes.map(viaje => ({
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
        vehiculo: viaje.vehiculo,
        conductor: {
          id: viaje.usuario_id._id,
          nombre: viaje.usuario_id.nombre,
          calificacion: viaje.usuario_id.calificacion,
          foto: viaje.usuario_id.foto_perfil
        }
      }
    }));

    res.json({
      mensaje: `${marcadores.length} viajes disponibles en el mapa`,
      marcadores: marcadores
    });

  } catch (error) {
    console.error('Error al obtener viajes para mapa:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
};
```

### 4. **Unirse a un Viaje**
```javascript
const unirseAViaje = async (req, res) => {
  try {
    const { viajeId } = req.params;
    const { pasajeros_solicitados = 1, mensaje } = req.body;
    const usuarioId = req.user.id;

    // Buscar el viaje
    const viaje = await Viaje.findById(viajeId)
      .populate('usuario_id', 'nombre email');

    if (!viaje) {
      return res.status(404).json({
        error: 'Viaje no encontrado'
      });
    }

    // Validaciones
    if (viaje.estado !== 'activo') {
      return res.status(400).json({
        error: 'Este viaje ya no está disponible'
      });
    }

    if (viaje.usuario_id._id.toString() === usuarioId) {
      return res.status(400).json({
        error: 'No puedes unirte a tu propio viaje'
      });
    }

    if (viaje.plazas_disponibles < pasajeros_solicitados) {
      return res.status(400).json({
        error: `Solo hay ${viaje.plazas_disponibles} plazas disponibles`
      });
    }

    // Verificar si ya se unió
    const yaUnido = viaje.pasajeros.some(p => 
      p.usuario_id.toString() === usuarioId
    );

    if (yaUnido) {
      return res.status(400).json({
        error: 'Ya tienes una solicitud pendiente para este viaje'
      });
    }

    // Agregar solicitud de pasajero
    viaje.pasajeros.push({
      usuario_id: usuarioId,
      estado: 'pendiente',
      pasajeros_solicitados: pasajeros_solicitados,
      mensaje: mensaje
    });

    // Reducir plazas disponibles (se pueden restaurar si se rechaza)
    viaje.plazas_disponibles -= pasajeros_solicitados;

    await viaje.save();

    // Notificar al conductor (implementar según sistema de notificaciones)
    // await enviarNotificacion(viaje.usuario_id._id, {
    //   tipo: 'nueva_solicitud_viaje',
    //   mensaje: `Tienes una nueva solicitud para tu viaje a ${viaje.destino.nombre}`
    // });

    res.json({
      mensaje: 'Solicitud enviada exitosamente',
      estado: 'pendiente'
    });

  } catch (error) {
    console.error('Error al unirse a viaje:', error);
    res.status(500).json({
      error: 'Error interno del servidor'
    });
  }
};
```

---

## 🗺️ IMPLEMENTACIÓN FRONTEND FLUTTER

### 1. **Servicio de API para Viajes**
```dart
// services/viaje_service.dart
class ViajeService {
  static const String baseUrl = 'http://tu-api.com/api';
  
  // Buscar viajes con radio de 500m
  static Future<List<Viaje>> buscarViajesPorProximidad({
    required double origenLat,
    required double origenLon,
    required double destinoLat,
    required double destinoLon,
    required String fecha,
    int pasajeros = 1,
    double radio = 0.5, // 500 metros
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/viajes/buscar-proximidad').replace(
        queryParameters: {
          'origen_lat': origenLat.toString(),
          'origen_lon': origenLon.toString(),
          'destino_lat': destinoLat.toString(),
          'destino_lon': destinoLon.toString(),
          'fecha': fecha,
          'pasajeros': pasajeros.toString(),
          'radio': radio.toString(),
        },
      ),
      headers: {'Authorization': 'Bearer ${await getToken()}'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['viajes'] as List)
          .map((viaje) => Viaje.fromJson(viaje))
          .toList();
    } else {
      throw Exception('Error al buscar viajes');
    }
  }

  // Obtener marcadores para el mapa
  static Future<List<MarcadorViaje>> obtenerMarcadoresViajes({
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/viajes/mapa').replace(
        queryParameters: {
          if (fechaDesde != null) 'fecha_desde': fechaDesde,
          if (fechaHasta != null) 'fecha_hasta': fechaHasta,
        },
      ),
      headers: {'Authorization': 'Bearer ${await getToken()}'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['marcadores'] as List)
          .map((marcador) => MarcadorViaje.fromJson(marcador))
          .toList();
    } else {
      throw Exception('Error al obtener marcadores');
    }
  }

  // Unirse a un viaje
  static Future<bool> unirseAViaje(String viajeId, {
    int pasajeros = 1,
    String? mensaje,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/viajes/$viajeId/unirse'),
      headers: {
        'Authorization': 'Bearer ${await getToken()}',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'pasajeros_solicitados': pasajeros,
        if (mensaje != null) 'mensaje': mensaje,
      }),
    );

    return response.statusCode == 200;
  }
}
```

### 2. **Modelo de Datos**
```dart
// models/marcador_viaje.dart
class MarcadorViaje {
  final String id;
  final UbicacionViaje origen;
  final UbicacionViaje destino;
  final DetallesViaje detallesViaje;

  MarcadorViaje({
    required this.id,
    required this.origen,
    required this.destino,
    required this.detallesViaje,
  });

  factory MarcadorViaje.fromJson(Map<String, dynamic> json) {
    return MarcadorViaje(
      id: json['id'],
      origen: UbicacionViaje.fromJson(json['origen']),
      destino: UbicacionViaje.fromJson(json['destino']),
      detallesViaje: DetallesViaje.fromJson(json['detalles_viaje']),
    );
  }
}

class UbicacionViaje {
  final List<double> coordinates; // [lon, lat]
  final String nombre;

  UbicacionViaje({
    required this.coordinates,
    required this.nombre,
  });

  factory UbicacionViaje.fromJson(Map<String, dynamic> json) {
    return UbicacionViaje(
      coordinates: List<double>.from(json['coordinates']),
      nombre: json['nombre'],
    );
  }

  double get latitud => coordinates[1];
  double get longitud => coordinates[0];
}

class DetallesViaje {
  final DateTime fecha;
  final String hora;
  final double precio;
  final int plazasDisponibles;
  final Vehiculo vehiculo;
  final Conductor conductor;

  DetallesViaje({
    required this.fecha,
    required this.hora,
    required this.precio,
    required this.plazasDisponibles,
    required this.vehiculo,
    required this.conductor,
  });

  factory DetallesViaje.fromJson(Map<String, dynamic> json) {
    return DetallesViaje(
      fecha: DateTime.parse(json['fecha']),
      hora: json['hora'],
      precio: json['precio'].toDouble(),
      plazasDisponibles: json['plazas_disponibles'],
      vehiculo: Vehiculo.fromJson(json['vehiculo']),
      conductor: Conductor.fromJson(json['conductor']),
    );
  }
}
```

### 3. **Widget de Mapa Interactivo**
```dart
// widgets/mapa_viajes_widget.dart
class MapaViajesWidget extends StatefulWidget {
  @override
  _MapaViajesWidgetState createState() => _MapaViajesWidgetState();
}

class _MapaViajesWidgetState extends State<MapaViajesWidget> {
  late MapController mapController;
  List<MarcadorViaje> marcadores = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _cargarMarcadores();
  }

  Future<void> _cargarMarcadores() async {
    try {
      final marcadoresObtenidos = await ViajeService.obtenerMarcadoresViajes();
      setState(() {
        marcadores = marcadoresObtenidos;
        cargando = false;
      });
    } catch (e) {
      setState(() {
        cargando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar viajes: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        OSMFlutter(
          controller: mapController,
          osmOption: OSMOption(
            userTrackingOption: UserTrackingOption(
              enableTracking: true,
              unFollowUser: false,
            ),
            zoomOption: ZoomOption(
              initZoom: 12,
              minZoomLevel: 3,
              maxZoomLevel: 19,
            ),
            userLocationMarker: UserLocationMaker(
              personMarker: MarkerIcon(
                icon: Icon(
                  Icons.location_history_rounded,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              directionArrowMarker: MarkerIcon(
                icon: Icon(
                  Icons.double_arrow,
                  size: 48,
                ),
              ),
            ),
          ),
          onMapIsReady: (isReady) {
            if (isReady) {
              _agregarMarcadores();
            }
          },
        ),
        if (cargando)
          Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Future<void> _agregarMarcadores() async {
    for (final marcador in marcadores) {
      // Marcador de origen
      await mapController.addMarker(
        GeoPoint(
          marcador.origen.latitud,
          marcador.origen.longitud,
        ),
        markerIcon: MarkerIcon(
          icon: _crearIconoVehiculo(marcador.detallesViaje.vehiculo),
        ),
      );

      // Listener para clic en marcador
      mapController.listenerMapSingleTapping.addListener(() {
        _mostrarDetallesViaje(marcador);
      });
    }
  }

  Widget _crearIconoVehiculo(Vehiculo vehiculo) {
    IconData icono;
    Color color;

    switch (vehiculo.tipo.toLowerCase()) {
      case 'sedan':
        icono = Icons.directions_car;
        color = Colors.blue;
        break;
      case 'suv':
        icono = Icons.directions_car;
        color = Colors.green;
        break;
      case 'hatchback':
        icono = Icons.directions_car_filled;
        color = Colors.orange;
        break;
      default:
        icono = Icons.directions_car;
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icono,
        color: color,
        size: 24,
      ),
    );
  }

  void _mostrarDetallesViaje(MarcadorViaje marcador) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Indicador de arrastre
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Información del conductor
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: marcador.detallesViaje.conductor.foto != null
                            ? NetworkImage(marcador.detallesViaje.conductor.foto!)
                            : null,
                        child: marcador.detallesViaje.conductor.foto == null
                            ? Icon(Icons.person)
                            : null,
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              marcador.detallesViaje.conductor.nombre,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                Text(' ${marcador.detallesViaje.conductor.calificacion}/5'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Información del viaje
                  _construirInfoItem(
                    icono: Icons.location_on,
                    titulo: 'Origen',
                    valor: marcador.origen.nombre,
                  ),
                  _construirInfoItem(
                    icono: Icons.location_on_outlined,
                    titulo: 'Destino',
                    valor: marcador.destino.nombre,
                  ),
                  _construirInfoItem(
                    icono: Icons.calendar_today,
                    titulo: 'Fecha',
                    valor: DateFormat('dd/MM/yyyy').format(marcador.detallesViaje.fecha),
                  ),
                  _construirInfoItem(
                    icono: Icons.access_time,
                    titulo: 'Hora',
                    valor: marcador.detallesViaje.hora,
                  ),
                  _construirInfoItem(
                    icono: Icons.attach_money,
                    titulo: 'Precio',
                    valor: '\$${marcador.detallesViaje.precio.toStringAsFixed(0)}',
                  ),
                  _construirInfoItem(
                    icono: Icons.people,
                    titulo: 'Plazas disponibles',
                    valor: '${marcador.detallesViaje.plazasDisponibles}',
                  ),

                  // Información del vehículo
                  SizedBox(height: 20),
                  Text(
                    'Vehículo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _crearIconoVehiculo(marcador.detallesViaje.vehiculo),
                        SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${marcador.detallesViaje.vehiculo.marca} ${marcador.detallesViaje.vehiculo.modelo}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text('${marcador.detallesViaje.vehiculo.color} • ${marcador.detallesViaje.vehiculo.patente}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),

                  // Botón para unirse
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _unirseAlViaje(marcador.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Unirse al viaje',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirInfoItem({
    required IconData icono,
    required String titulo,
    required String valor,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icono, color: Colors.grey[600]),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  valor,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unirseAlViaje(String viajeId) async {
    try {
      Navigator.pop(context); // Cerrar modal

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Enviando solicitud...'),
            ],
          ),
        ),
      );

      final exito = await ViajeService.unirseAViaje(viajeId);
      Navigator.pop(context); // Cerrar diálogo de carga

      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Solicitud enviada exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Error al enviar solicitud');
      }
    } catch (e) {
      Navigator.pop(context); // Cerrar diálogo de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

---

## 🛤️ RUTAS DE API

### **routes/viaje.routes.js**
```javascript
const express = require('express');
const router = express.Router();
const viajeController = require('../controllers/viaje.controller');
const { validarCrearViaje } = require('../validations/viaje.validation');
const { verificarToken } = require('../middlewares/authentication.middleware');

// Crear viaje
router.post('/crear', 
  verificarToken, 
  validarCrearViaje, 
  viajeController.crearViaje
);

// Buscar viajes por proximidad (radio de 500m)
router.get('/buscar-proximidad', 
  verificarToken, 
  viajeController.buscarViajesPorProximidad
);

// Obtener marcadores para mapa
router.get('/mapa', 
  verificarToken, 
  viajeController.obtenerViajesParaMapa
);

// Unirse a un viaje
router.post('/:viajeId/unirse', 
  verificarToken, 
  viajeController.unirseAViaje
);

// Gestionar solicitudes de pasajeros (conductor)
router.put('/:viajeId/solicitud/:solicitudId', 
  verificarToken, 
  viajeController.gestionarSolicitudPasajero
);

module.exports = router;
```

---

## 📱 RESULTADO ESPERADO

### **Funcionalidades Implementadas:**

1. **✅ Búsqueda con Radio de 500m**
   - Encuentra viajes cerca del origen Y destino especificados
   - Usa índices geoespaciales de MongoDB para eficiencia
   - Retorna distancia exacta en metros

2. **✅ Mapa Interactivo**
   - Muestra íconos de vehículos en puntos de origen
   - Íconos diferenciados por tipo de vehículo
   - Carga eficiente de marcadores

3. **✅ Modal de Detalles al Hacer Clic**
   - Información completa del viaje
   - Datos del conductor y vehículo
   - Botón funcional para unirse

4. **✅ Sistema de Solicitudes**
   - Envío de solicitudes de unión
   - Control de plazas disponibles
   - Estados de solicitud (pendiente/confirmado/rechazado)

### **Beneficios para Usuarios:**
- **Pasajeros**: Mayor probabilidad de encontrar viajes compatibles
- **Conductores**: Mayor alcance para atraer pasajeros
- **UX**: Interfaz intuitiva con mapa interactivo

---

*Implementación completa para búsqueda geoespacial y mapa interactivo - BioRuta*