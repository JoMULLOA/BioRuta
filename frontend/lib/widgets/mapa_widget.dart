import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class MapaWidget extends StatelessWidget {
  final MapController controller;

  const MapaWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return OSMFlutter(
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
    );
  }
}
