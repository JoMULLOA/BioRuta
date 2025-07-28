import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'dart:math' as math;
import '../services/viaje_service.dart';
import '../models/marcador_viaje_model.dart';
import '../utils/date_utils.dart' as ChileDateUtils;
import 'vehiculo_icon_helper.dart';

class MapaViajesInteractivo extends StatefulWidget {
  @override
  _MapaViajesInteractivoState createState() => _MapaViajesInteractivoState();
}

class _MapaViajesInteractivoState extends State<MapaViajesInteractivo> {
  late MapController mapController;
  List<MarcadorViaje> marcadores = [];
  bool cargando = true;
  Map<String, GeoPoint> marcadoresEnMapa = {}; // Para tracking de marcadores

  @override
  void initState() {
    super.initState();
    mapController = MapController(
      initPosition: GeoPoint(latitude: -33.4489, longitude: -70.6693), // Santiago por defecto
    );
    _cargarMarcadores();
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  Future<void> _cargarMarcadores() async {
    try {
      setState(() {
        cargando = true;
      });

      final marcadoresObtenidos = await ViajeService.obtenerMarcadoresViajes();
      
      setState(() {
        marcadores = marcadoresObtenidos;
        cargando = false;
      });

      await _agregarMarcadoresAlMapa();
    } catch (e) {
      setState(() {
        cargando = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar viajes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _agregarMarcadoresAlMapa() async {
    // Limpiar marcadores existentes
    for (final punto in marcadoresEnMapa.values) {
      try {
        await mapController.removeMarker(punto);
      } catch (e) {
        // Ignorar errores al remover marcadores
      }
    }
    marcadoresEnMapa.clear();

    // Agregar nuevos marcadores
    for (final marcador in marcadores) {
      await _agregarMarcadorIndividual(marcador);
    }
  }

  Future<void> _agregarMarcadorIndividual(MarcadorViaje marcador) async {
    try {
      final geoPoint = GeoPoint(
        latitude: marcador.origen.latitud,
        longitude: marcador.origen.longitud,
      );

      // Obtener color basado en el vehículo
      final vehiculo = marcador.detallesViaje.vehiculo;
      final color = vehiculo != null ? 
        VehiculoIconHelper.obtenerColorIcono(vehiculo.modelo.split(' ').first) : 
        Colors.blue;
      
      await mapController.addMarker(
        geoPoint,
        markerIcon: MarkerIcon(
          icon: Icon(Icons.directions_car, color: color, size: 28),
        ),
      );

      marcadoresEnMapa[marcador.id] = geoPoint;
    } catch (e) {
      print('Error al agregar marcador ${marcador.id}: $e');
    }
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
                  if (marcador.detallesViaje.conductor != null) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.blue[100],
                          child: Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.blue[700],
                          ),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                marcador.detallesViaje.conductor!.nombre,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                'Conductor',
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
                    SizedBox(height: 20),
                  ],

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
                    valor: ChileDateUtils.DateUtils.obtenerFechaChile(marcador.detallesViaje.fecha),
                  ),
                  _construirInfoItem(
                    icono: Icons.access_time,
                    titulo: 'Hora',
                    valor: ChileDateUtils.DateUtils.obtenerHoraChile(marcador.detallesViaje.fecha),
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
                  if (marcador.detallesViaje.vehiculo != null) ...[
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
                      child: VehiculoIconHelper.crearInfoVehiculo(
                        marca: marcador.detallesViaje.vehiculo!.modelo.split(' ').first,
                        modelo: marcador.detallesViaje.vehiculo!.modelo,
                        color: marcador.detallesViaje.vehiculo!.color,
                        patente: marcador.detallesViaje.vehiculo!.patente,
                      ),
                    ),
                  ],

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
                        'Solicitar unirse al viaje',
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

      // Mostrar diálogo de carga
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

      final resultado = await ViajeService.unirseAViaje(viajeId);
      Navigator.pop(context); // Cerrar diálogo de carga

      if (resultado['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado['message']),
            backgroundColor: Colors.green,
          ),
        );
        
        // Recargar marcadores para actualizar plazas disponibles
        await _cargarMarcadores();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Cerrar diálogo de carga si está abierto
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Función auxiliar para calcular distancia entre dos puntos
  double _calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    // Implementación simplificada de la fórmula Haversine
    const double radioTierra = 6371000; // metros
    
    final double dLat = _gradosARadianes(lat2 - lat1);
    final double dLon = _gradosARadianes(lon2 - lon1);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_gradosARadianes(lat1)) * math.cos(_gradosARadianes(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return radioTierra * c;
  }

  double _gradosARadianes(double grados) {
    return grados * (math.pi / 180);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Viajes Disponibles'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarMarcadores,
            icon: Icon(Icons.refresh),
            tooltip: 'Actualizar viajes',
          ),
        ],
      ),
      body: Stack(
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
                _agregarMarcadoresAlMapa();
              }
            },
            onGeoPointClicked: (geoPoint) {
              // Buscar marcador cercano y mostrar detalles
              for (final entry in marcadoresEnMapa.entries) {
                final distancia = _calcularDistancia(
                  geoPoint.latitude,
                  geoPoint.longitude,
                  entry.value.latitude,
                  entry.value.longitude,
                );
                
                if (distancia <= 50) { // 50 metros de tolerancia
                  final marcador = marcadores.firstWhere(
                    (m) => m.id == entry.key,
                    orElse: () => marcadores.first,
                  );
                  _mostrarDetallesViaje(marcador);
                  break;
                }
              }
            },
          ),
          
          // Indicador de carga
          if (cargando)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Cargando viajes disponibles...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Contador de viajes
          if (!cargando)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                child: Text(
                  '${marcadores.length} viajes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
