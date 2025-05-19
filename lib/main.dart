import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioRuta',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Prototipo Mapa con OpenStreetMap'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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

  Future<void> centrarEnMiUbicacion() async {
  try {
    GeoPoint? miPosicion = await controller.myLocation();
    await controller.moveTo(miPosicion);
    debugPrint("📍 Mapa centrado en: ${miPosicion.latitude}, ${miPosicion.longitude}");
    } catch (e) {
    debugPrint("❌ Error al centrar en ubicación: $e");
  }
}

  Future<void> _solicitarPermisos() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      debugPrint("✅ Permiso de ubicación concedido");
    } else if (status.isDenied) {
      debugPrint("❌ Permiso de ubicación denegado");
      _mostrarDialogo("Permiso de ubicación denegado. El mapa podría no funcionar correctamente.");
    } else if (status.isPermanentlyDenied) {
      debugPrint("⚠️ Permiso denegado permanentemente. Abriendo configuración...");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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
      onPressed: () async {
        await centrarEnMiUbicacion();
      },
      tooltip: 'Centrar en mi ubicación',
      heroTag: 'centrar',
      child: const Icon(Icons.my_location),
    ),
    const SizedBox(height: 12),
    FloatingActionButton(
      onPressed: () async {
        await controller.addMarker(
          GeoPoint(latitude: -33.4489, longitude: -70.6693), // Santiago
          markerIcon: const MarkerIcon(
            icon: Icon(Icons.place, color: Colors.green, size: 56),
          ),
        );
      },
      tooltip: 'Agregar marcador',
      heroTag: 'marcador',
      child: const Icon(Icons.add_location),
    ),
  ],
),

    );
  }
}
