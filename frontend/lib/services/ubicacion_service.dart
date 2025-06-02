import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class UbicacionService {
  static Future<bool> verificarServiciosUbicacion() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  static Future<PermissionStatus> solicitarPermisos() async {
    return await Permission.location.request();
  }

  static void mostrarDialogoPermiso(BuildContext context, String mensaje) {
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

  static double obtenerZoomParaRegion(String region) {
    if (region.toLowerCase().contains('santiago') || 
        region.toLowerCase().contains('metropolitana')) {
      return 12.0;
    } else if (region.toLowerCase().contains('valparaíso') ||
               region.toLowerCase().contains('concepción') ||
               region.toLowerCase().contains('antofagasta')) {
      return 13.0;
    } else if (region.toLowerCase().contains('región')) {
      return 10.0;
    } else {
      return 14.0;
    }
  }
}
