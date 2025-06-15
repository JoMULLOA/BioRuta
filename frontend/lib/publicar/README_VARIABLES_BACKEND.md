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

*Documentación generada para BioRuta - Sistema de Carpooling*