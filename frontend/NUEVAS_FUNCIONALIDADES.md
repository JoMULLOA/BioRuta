# Nuevas Funcionalidades - Navegación en Resultados de Búsqueda

## 📱 Botones de Navegación Agregados

En la pantalla de **Resultados de Búsqueda** (`resultados_busqueda.dart`) se han agregado tres botones de navegación para cada viaje encontrado:

### 🗺️ Funcionalidades Implementadas:

#### 1. **Google Maps** 🌍
- **Función**: `_abrirGoogleMaps(viaje)`
- **Acción**: Abre Google Maps con navegación directa al origen del viaje
- **URL**: `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}&travelmode=driving`
- **Icono**: `Icons.map`
- **Color**: Azul

#### 2. **Waze** 🧭  
- **Función**: `_abrirWaze(viaje)`
- **Acción**: Abre Waze con navegación directa al origen del viaje
- **URL**: `https://waze.com/ul?ll={lat},{lng}&navigate=yes`
- **Icono**: `Icons.navigation`
- **Color**: Naranja

#### 3. **Ver Ruta** 🚗
- **Función**: `_mostrarRutaEnMapa(viaje)`
- **Acción**: Navega al mapa interno de la aplicación y muestra:
  - ✅ **Línea de ruta** desde ubicación actual hasta el punto de encuentro
  - ✅ **Marcador del vehículo** en el destino (punto de encuentro)
  - ✅ **Información del viaje** en SnackBar (conductor, vehículo, hora)
  - ✅ **Zoom automático** para mostrar toda la ruta
- **Icono**: `Icons.directions_car`
- **Color**: Café (Color de la app)

### 🎨 Diseño Visual:

```
┌─────────────────────────────────────────┐
│ Viaje Card                              │
│ ┌─────────────────────────────────────┐ │
│ │ [Conductor] [Precio]                │ │
│ │ [Origen → Destino]                  │ │
│ │ [Distancias de caminata]            │ │
│ │                                     │ │
│ │ ┌─ Navegar al punto de encuentro: ─┐│ │
│ │ │ [🗺️ Google Maps] [🧭 Waze] [🚗 Ver Ruta] │ │
│ │ └─────────────────────────────────┘ │ │
│ │                                     │ │
│ │ [Ver Detalles y Solicitar]          │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### 📱 Funcionalidad "Ver Ruta" en Detalle:

#### 🗺️ **En el Mapa Interno** (`mapa.dart`):
1. **Recibe argumentos** desde la pantalla de resultados:
   ```dart
   {
     'mostrarRuta': true,
     'origenLat': viaje.origen.latitud,
     'origenLng': viaje.origen.longitud,
     'origenNombre': viaje.origen.nombre,
     'conductorNombre': viaje.conductor?.nombre,
     'vehiculoPatente': viaje.vehiculoPatente,
     'horaViaje': viaje.horaIda,
   }
   ```

2. **Dibuja la ruta**:
   - Línea desde ubicación actual → punto de encuentro
   - Color: **Café** (`Color(0xFF854937)`) 
   - Grosor: **8px** con borde blanco
   - Estilo: Línea sólida

3. **Marca el vehículo**:
   - Icono: `Icons.directions_car`
   - Color: **Café** (`Color(0xFF854937)`)
   - Tamaño: **48px**

4. **Información contextual**:
   - SnackBar con datos del viaje por 5 segundos
   - Zoom automático para mostrar ruta completa

### 📋 Información Técnica:

#### Coordenadas utilizadas:
- **Latitud**: `viaje.origen.latitud`
- **Longitud**: `viaje.origen.longitud`

#### Manejo de errores:
- Verificación de `canLaunchUrl()` antes de abrir aplicaciones
- Mensajes de error informativos si la aplicación no está instalada
- Fallbacks para casos donde no se puede acceder a las coordenadas

#### Dependencias:
- **url_launcher**: `^6.2.2` (ya incluida en pubspec.yaml)
- **flutter_osm_plugin**: Para dibujar rutas en el mapa interno

### 🚀 Flujo de Usuario:

1. **Búsqueda de viajes**: El usuario busca viajes como siempre
2. **Resultados mostrados**: Se muestran las tarjetas de viajes disponibles
3. **Navegación externa**:
   - **Google Maps** → Se abre Google Maps con la ruta
   - **Waze** → Se abre Waze con la ruta  
4. **Navegación interna**:
   - **Ver Ruta** → Va al mapa de la app y muestra:
     - 🗺️ Línea de ruta trazada
     - 🚗 Marcador del vehículo
     - 📍 Información del punto de encuentro
5. **Punto de encuentro**: Todas las rutas llevan al origen del viaje (donde está el conductor)

### 💡 Beneficios:

- ✅ **Conveniencia**: Navegación directa sin copiar direcciones
- ✅ **Flexibilidad**: El usuario elige su método de navegación preferido
- ✅ **Visualización clara**: Ruta trazada en el mapa interno
- ✅ **Información contextual**: Datos del conductor y vehículo
- ✅ **Integración nativa**: Usa las apps instaladas en el dispositivo
- ✅ **Experiencia mejorada**: Flujo más fluido para encontrar al conductor

---

## 🔧 Archivos Modificados:

### 1. **`resultados_busqueda.dart`**:
- ✅ Agregados 3 botones de navegación
- ✅ Funciones para Google Maps y Waze
- ✅ Función para navegar al mapa interno
- ✅ Manejo de argumentos para pasar datos al mapa

### 2. **`mapa.dart`**:
- ✅ Variables para manejar ruta específica de viaje
- ✅ Manejo de argumentos en `build()`
- ✅ Función `_mostrarRutaHaciaViaje()` para dibujar ruta
- ✅ Marcador del vehículo en destino
- ✅ Zoom automático para mostrar ruta completa
- ✅ SnackBar informativo con datos del viaje

## 📱 Compatibilidad:

- ✅ **Android**: Funcionamiento completo
- ✅ **iOS**: Funcionamiento completo  
- ✅ **Web**: URLs externas se abren en nueva pestaña

## 🎯 Resultado Final:

Los usuarios ahora pueden:
1. **Ver rutas externas** → Google Maps / Waze
2. **Ver ruta interna** → Mapa de la app con línea trazada y marcador del vehículo
3. **Información completa** → Conductor, vehículo, hora y punto de encuentro
4. **Navegación fluida** → Un clic desde resultados hasta el mapa con ruta
