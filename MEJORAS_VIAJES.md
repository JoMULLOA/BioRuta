# Mejoras en el Sistema de Viajes - BioRuta

## Cambios Implementados

### 1. Filtrado Automático de Viajes Expirados

**Problema**: Los viajes seguían apareciendo en el mapa después de que pasara su hora de salida.

**Solución Implementada**:
- **Filtrado en tiempo real**: Los marcadores de viajes en el mapa ahora se filtran automáticamente considerando la zona horaria chilena (UTC-4).
- **Cambio de estado automático**: Cuando un viaje pasa su hora de salida (+5 minutos de gracia), se cambia automáticamente de "activo" a "en_curso".
- **Monitoreo continuo**: Se implementó un sistema de monitoreo cada 2 minutos que verifica viajes que han pasado su hora.

**Archivos modificados**:
- `frontend/lib/services/viaje_service.dart`: Filtrado en `obtenerMarcadoresViajes()`
- `frontend/lib/services/viaje_state_monitor.dart`: **Nuevo archivo** - Monitor automático
- `frontend/lib/mapa/mapa.dart`: Integración del monitor y filtrado en radar

### 2. Validación de Viajes Solapados

**Problema**: Los usuarios podían publicar viajes que se solapaban en tiempo, considerando la duración estimada del viaje.

**Solución Implementada**:
- **Cálculo de duración**: 1 hora por cada 90 kilómetros de distancia.
- **Validación antes de publicar**: Verifica conflictos con viajes activos del usuario.
- **Validación de viajes de vuelta**: También valida que el viaje de vuelta no se solape.
- **Interfaz informativa**: Muestra duración estimada y próximo tiempo disponible.

**Archivos creados/modificados**:
- `frontend/lib/utils/viaje_validator.dart`: **Nuevo archivo** - Utilidades de validación
- `frontend/lib/services/viaje_service.dart`: Método `validarPublicacionViaje()`
- `frontend/lib/publicar/publicar_viaje_final.dart`: Validación antes de crear viaje
- `frontend/lib/publicar/publicar_viaje_paso2.dart`: Validación en fecha de vuelta

## Características Técnicas

### Gestión de Zona Horaria
- **Backend**: Almacena fechas en UTC (buenas prácticas)
- **Frontend**: Convierte a zona horaria chilena (UTC-4) para mostrar al usuario
- **Validaciones**: Todas las comparaciones de tiempo consideran UTC-4

### Cálculo de Duración de Viajes
```dart
// Fórmula: 1 hora cada 90 kilómetros
Duration duracion = Duration(minutes: (distanciaKm / 90.0 * 60).round());
```

### Monitoreo Automático
- **Intervalo**: Cada 2 minutos
- **Gracia**: 5 minutos después de la hora de salida
- **Cambio de estado**: De "activo" a "en_curso" automáticamente

## Beneficios

1. **UX Mejorada**: Los usuarios ya no ven viajes que no están disponibles
2. **Integridad de datos**: Los estados de viajes se mantienen consistentes
3. **Prevención de conflictos**: No se pueden crear viajes que se solapen
4. **Transparencia**: Los usuarios ven la duración estimada de sus viajes
5. **Automatización**: Reduce la intervención manual para gestionar estados

## Uso

### Para el Usuario
- Al publicar un viaje, el sistema valida automáticamente conflictos
- Se muestra la duración estimada del viaje
- Si hay conflicto, se informa el próximo tiempo disponible

### Para el Mapa
- Los viajes expirados desaparecen automáticamente
- El radar también filtra viajes pasados
- Los marcadores se actualizan en tiempo real

## Configuración

El monitoreo se inicia automáticamente cuando se carga el mapa y se detiene al cerrar la pantalla. No requiere configuración adicional.
