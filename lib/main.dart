import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter OSM Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Mapa con OpenStreetMap'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await controller.addMarker(
            GeoPoint(latitude: -33.4489, longitude: -70.6693), // Santiago
            markerIcon: const MarkerIcon(
              icon: Icon(Icons.place, color: Colors.green, size: 56),
            ),
          );
        },
        tooltip: 'Agregar marcador',
        child: const Icon(Icons.add_location),
      ),
    );
  }
}
