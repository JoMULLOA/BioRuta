import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../navbar_widget.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class DireccionSugerida {
  final String displayName;
  final double lat;
  final double lon;
  double distancia;

  DireccionSugerida({
    required this.displayName,
    required this.lat,
    required this.lon,
    this.distancia = 0.0,
  });

  factory DireccionSugerida.fromJson(Map<String, dynamic> json) {
    return DireccionSugerida(
      displayName: json['display_name'],
      lat: double.parse(json['lat']),
      lon: double.parse(json['lon']),
    );
  }
}

class _MapPageState extends State<MapPage> {
  late MapController controller;
  final TextEditingController destinoController = TextEditingController();
  int _selectedIndex = 0;
  List<DireccionSugerida> _sugerencias = [];
  bool _mostrandoSugerencias = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    controller = MapController.withUserPosition(
      trackUserLocation: const UserTrackingOption(
        enableTracking: true,
        unFollowUser: false,
      ),
    );
    _verificarServiciosUbicacion();
  }

  Future<void> _verificarServiciosUbicacion() async {
    final serviciosActivos = await Geolocator.isLocationServiceEnabled();
    if (!serviciosActivos) {
      _mostrarDialogo("Por favor activa los servicios de ubicación desde los ajustes del sistema.");
      return;
    }
    _solicitarPermisos();
  }

  Future<void> buscarSugerencias(String query) async {
    if (query.length < 4) {
      setState(() {
        _sugerencias = [];
        _mostrandoSugerencias = false;
      });
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _ejecutarBusqueda(query);
    });
  }

  // 1. MÉTODO PRINCIPAL - Ejecuta búsqueda y ordena por distancia
  Future<void> _ejecutarBusqueda(String query) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(query)}&'
        'format=json&'
        'limit=15&'
        'countrycodes=cl'
      );

      final respuesta = await http.get(url, headers: {
        'User-Agent': 'flutter_bioruta_app',
      });

      if (respuesta.statusCode == 200) {
        final List<dynamic> data = json.decode(respuesta.body);
        List<DireccionSugerida> sugerenciasRaw = data
            .map((item) => DireccionSugerida.fromJson(item))
            .toList();

        GeoPoint? ubicacionActual = await controller.myLocation();
        
        if (ubicacionActual != null && sugerenciasRaw.isNotEmpty) {
          // AQUÍ SE CALCULA LA DISTANCIA
          _calcularDistancias(sugerenciasRaw, ubicacionActual);
          
          // AQUÍ SE ORDENAN POR DISTANCIA (menor a mayor)
          sugerenciasRaw.sort((a, b) => a.distancia.compareTo(b.distancia));
          final mejoresSugerencias = sugerenciasRaw.take(5).toList();
          
          if (mounted) {
            setState(() {
              _sugerencias = mejoresSugerencias;
              _mostrandoSugerencias = true;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _sugerencias = sugerenciasRaw.take(5).toList();
              _mostrandoSugerencias = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error al buscar sugerencias: $e');
    }
  }

  // 2. MÉTODO DE CÁLCULO DE DISTANCIAS
  void _calcularDistancias(List<DireccionSugerida> sugerencias, GeoPoint ubicacionUsuario) {
    if (sugerencias.isEmpty) return;
    
    // Calcular distancias usando Haversine
    for (var sugerencia in sugerencias) {
      double distancia = _calcularDistanciaHaversine(
        ubicacionUsuario.latitude,
        ubicacionUsuario.longitude,
        sugerencia.lat,
        sugerencia.lon,
      );
      sugerencia.distancia = distancia;
    }
  }

  // 3. MÉTODO HAVERSINE - Calcula distancia geográfica real
  double _calcularDistanciaHaversine(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radio de la Tierra en km
    
    double dLat = _gradosARadianes(lat2 - lat1);
    double dLon = _gradosARadianes(lon2 - lon1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_gradosARadianes(lat1)) * math.cos(_gradosARadianes(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return R * c; // Distancia en km
  }

  // 4. MÉTODO AUXILIAR - Convierte grados a radianes
  double _gradosARadianes(double grados) {
    return grados * (math.pi / 180);
  }

  Future<void> _solicitarPermisos() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      debugPrint("✅ Permiso de ubicación concedido");
      await centrarEnMiUbicacion();
    } else if (status.isDenied) {
      _mostrarDialogo("Permiso de ubicación denegado. El mapa podría no funcionar correctamente.");
    } else if (status.isPermanentlyDenied) {
      _mostrarDialogo("Debes activar el permiso de ubicación manualmente en los ajustes.");
      await openAppSettings();
    }
  }

  void _mostrarDialogo(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permiso de ubicación"),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> centrarEnMiUbicacion() async {
    try {
      GeoPoint? miPosicion = await controller.myLocation();
      if (miPosicion == null) {
        if (mounted) {
          _mostrarDialogo("No se pudo obtener tu ubicación actual.");
        }
        return;
      }
      await controller.moveTo(miPosicion);
      debugPrint("📍 Mapa centrado en: ${miPosicion.latitude}, ${miPosicion.longitude}");
    } catch (e) {
      debugPrint("❌ Error al centrar en ubicación: $e");
    }
  }

  Future<GeoPoint?> buscarDireccionConNominatim(String direccion) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(direccion)}&format=json&limit=1&countrycodes=cl');

    final respuesta = await http.get(url, headers: {
      'User-Agent': 'flutter_bioruta_app',
    });

    if (respuesta.statusCode == 200) {
      final data = json.decode(respuesta.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        return GeoPoint(latitude: lat, longitude: lon);
      }
    }
    return null;
  }

  Future<void> buscarYDibujarRuta(String destinoTexto) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔍 Buscando dirección...')),
      );
    }

    final destinoPunto = await buscarDireccionConNominatim(destinoTexto);
    if (destinoPunto == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Dirección no encontrada')),
        );
      }
      return;
    }

    try {
      final origen = await controller.myLocation();
      if (origen == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ No se pudo obtener tu ubicación actual')),
          );
        }
        return;
      }

      await controller.removeLastRoad();

      await controller.drawRoad(
        origen,
        destinoPunto,
        roadType: RoadType.car,
        roadOption: const RoadOption(
          roadColor: Colors.purple,
        ),
      );

      await controller.moveTo(destinoPunto);

      await controller.addMarker(
        destinoPunto,
        markerIcon: const MarkerIcon(
          icon: Icon(Icons.flag, color: Colors.orange, size: 56),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📍 Ruta trazada exitosamente')),
        );
      }
    } catch (e) {
      debugPrint("❌ Error al trazar ruta: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Ocurrió un error al trazar la ruta')),
        );
      }
    }
  }

  @override
  void dispose() {
    destinoController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mapa de BioRuta"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          OSMFlutter(
            controller: controller,
            osmOption: OSMOption(
              userTrackingOption: const UserTrackingOption(
                enableTracking: true,
                unFollowUser: false,
              ),
              zoomOption: ZoomOption(
                initZoom: 14,
                minZoomLevel: 4,
                maxZoomLevel: 18,
                stepZoom: 1.0,
              ),
              userLocationMarker: UserLocationMaker(
                personMarker: const MarkerIcon(
                  icon: Icon(Icons.person_pin_circle, color: Colors.blue, size: 56),
                ),
                directionArrowMarker: const MarkerIcon(
                  icon: Icon(Icons.navigation, color: Colors.red, size: 48),
                ),
              ),
              roadConfiguration: const RoadOption(roadColor: Colors.purple),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: TextField(
                      controller: destinoController,
                      onChanged: (value) => buscarSugerencias(value),
                      decoration: InputDecoration(
                        hintText: 'Escribe una dirección o lugar (mín. 4 caracteres)',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (destinoController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    destinoController.clear();
                                    _sugerencias = [];
                                    _mostrandoSugerencias = false;
                                  });
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                final destino = destinoController.text.trim();
                                if (destino.isNotEmpty) {
                                  buscarYDibujarRuta(destino);
                                  setState(() {
                                    _mostrandoSugerencias = false;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                if (_mostrandoSugerencias && _sugerencias.isNotEmpty)
                  Card(
                    elevation: 8,
                    margin: const EdgeInsets.only(top: 4),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _sugerencias.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                            _sugerencias[index].displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Distancia: ${_sugerencias[index].distancia.toStringAsFixed(2)} km',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            destinoController.text = _sugerencias[index].displayName;
                            buscarYDibujarRuta(_sugerencias[index].displayName);
                            setState(() {
                              _mostrandoSugerencias = false;
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomNavbar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'centrar',
            onPressed: () async => await centrarEnMiUbicacion(),
            tooltip: 'Centrar en mi ubicación',
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'marcador',
            onPressed: () async {
              await controller.addMarker(
                GeoPoint(latitude: -33.4489, longitude: -70.6693),
                markerIcon: const MarkerIcon(
                  icon: Icon(Icons.place, color: Colors.green, size: 56),
                ),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📍 Marcador agregado en Santiago')),
                );
              }
            },
            tooltip: 'Agregar marcador',
            child: const Icon(Icons.add_location),
          ),
        ],
      ),
    );
  }
}