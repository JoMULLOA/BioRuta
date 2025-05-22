import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:permission_handler/permission_handler.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late MapController controller;

  @override
  void initState() {
    super.initState();
    controller = MapController.withUserPosition(
      trackUserLocation: const UserTrackingOption(
        enableTracking: true,
        unFollowUser: false,
      ),
    );
    _solicitarPermisos();
  }

  Future<void> _solicitarPermisos() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      debugPrint("✅ Permiso de ubicación concedido");
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
      await controller.moveTo(miPosicion);
      debugPrint("📍 Mapa centrado en: ${miPosicion.latitude}, ${miPosicion.longitude}");
    } catch (e) {
      debugPrint("❌ Error al centrar en ubicación: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mapa de BioRuta"),
        backgroundColor: Colors.deepPurple,
      ),
      body: OSMFlutter(
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
          roadConfiguration: RoadOption(roadColor: Colors.purple),
        ),
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
            },
            tooltip: 'Agregar marcador',
            child: const Icon(Icons.add_location),
          ),
        ],
      ),
    );
  }
}
