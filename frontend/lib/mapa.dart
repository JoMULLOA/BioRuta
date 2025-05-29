import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'navbar_widget.dart'; // Reemplaza "tu_app" con el nombre real de tu proyecto

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late MapController controller;
  final TextEditingController destinoController = TextEditingController();
  int _selectedIndex = 0;

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
        _mostrarDialogo("No se pudo obtener tu ubicación actual.");
        return;
      }
      await controller.goToLocation(miPosicion);
      debugPrint("📍 Mapa centrado en: ${miPosicion.latitude}, ${miPosicion.longitude}");
    } catch (e) {
      debugPrint("❌ Error al centrar en ubicación: $e");
    }
  }

  Future<GeoPoint?> buscarDireccionConNominatim(String direccion) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(direccion)}&format=json&limit=1');

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔍 Buscando dirección...')),
    );

    final destinoPunto = await buscarDireccionConNominatim(destinoTexto);
    if (destinoPunto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Dirección no encontrada')),
      );
      return;
    }

    try {
      final origen = await controller.myLocation();
      if (origen == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ No se pudo obtener tu ubicación actual')),
        );
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

      await controller.goToLocation(destinoPunto);

      await controller.addMarker(
        destinoPunto,
        markerIcon: const MarkerIcon(
          icon: Icon(Icons.flag, color: Colors.orange, size: 56),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📍 Ruta trazada exitosamente')),
      );
    } catch (e) {
      debugPrint("❌ Error al trazar ruta: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Ocurrió un error al trazar la ruta')),
      );
    }
  }

  @override
  void dispose() {
    destinoController.dispose();
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
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  controller: destinoController,
                  decoration: InputDecoration(
                    hintText: 'Escribe una dirección o lugar',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        final destino = destinoController.text.trim();
                        if (destino.isNotEmpty) {
                          buscarYDibujarRuta(destino);
                        }
                      },
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomNavbar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // Aquí puedes agregar navegación condicional si quieres cambiar de pantalla
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📍 Marcador agregado en Santiago')),
              );
            },
            tooltip: 'Agregar marcador',
            child: const Icon(Icons.add_location),
          ),
        ],
      ),
    );
  }
}
