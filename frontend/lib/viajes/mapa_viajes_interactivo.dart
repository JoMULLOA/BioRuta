import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'dart:math' as math;
import '../services/viaje_service.dart';
import '../models/marcador_viaje_model.dart';
import 'vehiculo_icon_helper.dart';

class MapaViajesInteractivo extends StatefulWidget {
  const MapaViajesInteractivo({super.key});

  @override
  _MapaViajesInteractivoState createState() => _MapaViajesInteractivoState();
}

class _MapaViajesInteractivoState extends State<MapaViajesInteractivo> {
  late MapController mapController;
  List<MarcadorViaje> marcadores = [];
  bool cargando = true;
  bool mapReady = false;
  Map<String, GeoPoint> marcadoresEnMapa = {}; // Para tracking de marcadores

  // Coordenadas de Concepción, Chile
  static const double latConcepcion = -36.8201;
  static const double lngConcepcion = -73.0444;

  @override
  void initState() {
    super.initState();
    mapController = MapController(
      initPosition: GeoPoint(latitude: latConcepcion, longitude: lngConcepcion),
    );
    
    // Esperar a que el mapa esté listo antes de cargar marcadores
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
  Future<void> _initializeMap() async {
    try {
      // Esperar un momento para que el mapa se inicialice
      await Future.delayed(const Duration(seconds: 2));
      
      // Centrar explícitamente en Concepción
      await _centrarEnConcepcion();
      
      setState(() {
        mapReady = true;
      });
      
      await _cargarMarcadores();
    } catch (e) {
      print('Error inicializando mapa: $e');
    }
  }
  Future<void> _cargarMarcadores() async {
    if (!mapReady) return;
    
    try {
      setState(() {
        cargando = true;
      });

      print('🔄 Intentando cargar marcadores de viajes...');
      
      // Obtener marcadores de viajes
      final marcadoresObtenidos = await ViajeService.obtenerMarcadoresViajes();
      
      print('✅ Marcadores obtenidos: ${marcadoresObtenidos.length}');
      
      setState(() {
        marcadores = marcadoresObtenidos;
        cargando = false;
      });

      await _agregarMarcadoresAlMapa();
    } catch (e) {
      print('❌ Error al cargar marcadores: $e');
      
      setState(() {
        cargando = false;
      });
      
      // Determinar tipo de error y mostrar mensaje específico
      String mensajeError = 'Error al cargar viajes';
      
      if (e.toString().contains('Connection refused')) {
        mensajeError = 'No se puede conectar al servidor. ¿Está corriendo el backend?';
      } else if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        mensajeError = 'Error de autenticación. Intenta cerrar sesión e iniciar nuevamente';
      } else if (e.toString().contains('500')) {
        mensajeError = 'Error del servidor. Contacta al administrador';
      } else {
        mensajeError = 'Error de conexión: ${e.toString()}';
      }
        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _agregarMarcadoresAlMapa() async {
    if (!mapReady || marcadores.isEmpty) return;

    try {
      // Limpiar marcadores existentes
      for (String markerId in marcadoresEnMapa.keys) {
        await mapController.removeMarker(marcadoresEnMapa[markerId]!);
      }
      marcadoresEnMapa.clear();

      // Agregar nuevos marcadores
      for (MarcadorViaje marcador in marcadores) {
        final geoPoint = GeoPoint(
          latitude: marcador.origen.latitud,
          longitude: marcador.origen.longitud,
        );

        // Generar ícono basado en el vehículo si está disponible
        final iconData = marcador.detallesViaje.vehiculo != null
            ? VehiculoIconHelper.obtenerIconoVehiculo(
                null, // marca no disponible en el modelo actual
                marcador.detallesViaje.vehiculo!.modelo,
              )
            : Icons.directions_car;
        
        final color = marcador.detallesViaje.vehiculo != null
            ? VehiculoIconHelper.obtenerColorIcono(null) // marca no disponible
            : Colors.blue;

        await mapController.addMarker(
          geoPoint,
          markerIcon: MarkerIcon(
            icon: Icon(
              iconData,
              color: color,
              size: 40,
            ),
          ),
        );        marcadoresEnMapa[marcador.id] = geoPoint;
      }
      
      // Asegurar que el mapa permanezca centrado en Concepción después de agregar marcadores
      await _centrarEnConcepcion();
      
    } catch (e) {
      print('Error agregando marcadores: $e');
    }
  }

  Future<void> _centrarEnConcepcion() async {
    if (!mapReady) return;
    
    try {
      await mapController.goToLocation(
        GeoPoint(latitude: latConcepcion, longitude: lngConcepcion),
      );
      
      await mapController.setZoom(zoomLevel: 12);
    } catch (e) {
      print('Error centrando en Concepción: $e');
    }
  }

  Future<void> _mostrarDetallesViaje(MarcadorViaje marcador) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildViajeDetailModal(marcador),
    );
  }

  Widget _buildViajeDetailModal(MarcadorViaje marcador) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con precio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detalles del Viaje',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF854937),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF854937),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '\$${marcador.detallesViaje.precio.toInt()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Ruta
                  _buildInfoSection(
                    'Ruta',
                    [
                      _buildRouteItem(
                        Icons.location_on,
                        Colors.green,
                        'Origen',
                        marcador.origen.nombre,
                      ),
                      _buildRouteItem(
                        Icons.location_on,
                        Colors.red,
                        'Destino',
                        marcador.destino.nombre,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Fecha y hora
                  _buildInfoSection(
                    'Horario',
                    [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            '${marcador.detallesViaje.fecha.day}/${marcador.detallesViaje.fecha.month}/${marcador.detallesViaje.fecha.year}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 20),
                          const Icon(Icons.access_time, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            marcador.detallesViaje.hora,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Conductor
                  if (marcador.detallesViaje.conductor != null)
                    _buildInfoSection(
                      'Conductor',
                      [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF854937),
                            child: Text(
                              marcador.detallesViaje.conductor!.nombre[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(marcador.detallesViaje.conductor!.nombre),
                          subtitle: const Text('⭐ Sin calificación'),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Vehículo
                  if (marcador.detallesViaje.vehiculo != null)
                    _buildInfoSection(
                      'Vehículo',
                      [
                        Row(
                          children: [
                            Icon(
                              VehiculoIconHelper.obtenerIconoVehiculo(
                                null,
                                marcador.detallesViaje.vehiculo!.modelo,
                              ),
                              color: VehiculoIconHelper.obtenerColorIcono(null),
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    marcador.detallesViaje.vehiculo!.modelo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${marcador.detallesViaje.vehiculo!.patente} • ${marcador.detallesViaje.vehiculo!.color}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${marcador.detallesViaje.plazasDisponibles} plazas disponibles',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  
                  const Spacer(),
                  
                  // Botón de unirse
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _unirseAlViaje(marcador),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF854937),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Unirse al Viaje',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF854937),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEDCAB6)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildRouteItem(IconData icon, Color color, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unirseAlViaje(MarcadorViaje marcador) async {
    try {
      await ViajeService.unirseAViaje(marcador.id);
      
      if (mounted) {
        Navigator.pop(context); // Cerrar modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Te has unido al viaje exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Recargar marcadores para actualizar información
        await _cargarMarcadores();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al unirse al viaje: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          OSMFlutter(
            controller: mapController,
            osmOption: OSMOption(
              userTrackingOption: const UserTrackingOption(
                enableTracking: false,
                unFollowUser: false,
              ),
              zoomOption: const ZoomOption(
                initZoom: 12,
                minZoomLevel: 3,
                maxZoomLevel: 19,
                stepZoom: 1.0,
              ),
              userLocationMarker: UserLocationMaker(
                personMarker: const MarkerIcon(
                  icon: Icon(
                    Icons.location_history_rounded,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                directionArrowMarker: const MarkerIcon(
                  icon: Icon(
                    Icons.double_arrow,
                    size: 48,
                  ),
                ),
              ),
              roadConfiguration: const RoadOption(
                roadColor: Colors.yellowAccent,
              ),
            ),            onMapIsReady: (ready) async {
              if (ready) {
                setState(() {
                  mapReady = true;
                });
                await _cargarMarcadores();
              }
            },
            onLocationChanged: (position) {
              print('Ubicación actual: ${position.latitude}, ${position.longitude}');
            },
            onGeoPointClicked: (geoPoint) async {
              // Buscar marcador clickeado
              for (MarcadorViaje marcador in marcadores) {
                final marcadorPoint = GeoPoint(
                  latitude: marcador.origen.latitud,
                  longitude: marcador.origen.longitud,
                );
                
                // Verificar si el clic está cerca del marcador (tolerancia de ~100m)
                final distancia = _calcularDistancia(
                  geoPoint.latitude,
                  geoPoint.longitude,
                  marcadorPoint.latitude,
                  marcadorPoint.longitude,
                );
                
                if (distancia < 100) {
                  await _mostrarDetallesViaje(marcador);
                  break;
                }
              }
            },
          ),
          
          // Indicador de carga
          if (cargando)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF854937)),
                ),
              ),
            ),
            // Botones flotantes
          Positioned(            bottom: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "refresh",
                  onPressed: _cargarMarcadores,
                  backgroundColor: const Color(0xFF854937),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.refresh),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "center",
                  onPressed: _centrarEnConcepcion,
                  backgroundColor: const Color(0xFFEDCAB6),
                  foregroundColor: const Color(0xFF070505),
                  child: const Icon(Icons.location_city),
                ),
              ],
            ),
          ),
          
          // Información de ubicación
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_city,
                    color: Color(0xFF854937),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Viajes en Concepción',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF854937),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF854937),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${marcadores.length} viajes',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Función para calcular distancia entre dos puntos geográficos
  double _calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Radio de la Tierra en metros
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }
}
