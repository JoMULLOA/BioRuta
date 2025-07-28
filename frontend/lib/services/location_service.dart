import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Verificar y solicitar permisos de ubicación
  static Future<bool> checkAndRequestLocationPermission() async {
    try {
      // Verificar permisos del sistema
      PermissionStatus permission = await Permission.location.status;
      
      if (permission.isDenied) {
        permission = await Permission.location.request();
      }
      
      if (permission.isPermanentlyDenied) {
        // El usuario negó permanentemente los permisos
        return false;
      }
      
      if (permission.isGranted) {
        // Verificar también con geolocator
        LocationPermission geoPermission = await Geolocator.checkPermission();
        
        if (geoPermission == LocationPermission.denied) {
          geoPermission = await Geolocator.requestPermission();
        }
        
        return geoPermission == LocationPermission.whileInUse || 
               geoPermission == LocationPermission.always;
      }
      
      return false;
    } catch (e) {
      print('❌ Error verificando permisos de ubicación: $e');
      return false;
    }
  }
  
  /// Obtener la ubicación actual del usuario
  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      // Verificar permisos primero
      bool hasPermission = await checkAndRequestLocationPermission();
      if (!hasPermission) {
        print('❌ Sin permisos de ubicación');
        return null;
      }
      
      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Servicio de ubicación deshabilitado');
        return null;
      }
      
      // Obtener la posición actual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      print('✅ Ubicación obtenida: ${position.latitude}, ${position.longitude}');
      
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp.millisecondsSinceEpoch,
      };
      
    } catch (e) {
      print('❌ Error obteniendo ubicación: $e');
      return null;
    }
  }
  
  /// Formatear coordenadas para mostrar al usuario
  static String formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
  
  /// Generar URL de Google Maps
  static String generateGoogleMapsUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps?q=$latitude,$longitude';
  }
  
  /// Calcular distancia entre dos puntos
  static double calculateDistance(
    double lat1, double lon1, 
    double lat2, double lon2
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
  
  /// Formatear distancia para mostrar al usuario
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }
}
