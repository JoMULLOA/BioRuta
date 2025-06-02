import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import '../models/direccion_sugerida.dart';

class BusquedaService {
  static const String _userAgent = 'flutter_bioruta_app';

  // Búsqueda con región específica
  static Future<List<DireccionSugerida>> buscarConRegion(String query, String region) async {
    try {
      final queryConRegion = '$query, $region, Chile';
      
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(queryConRegion)}&'
        'format=json&'
        'limit=3&'
        'countrycodes=cl'
      );

      final respuesta = await http.get(url, headers: {'User-Agent': _userAgent});

      if (respuesta.statusCode == 200) {
        final List<dynamic> data = json.decode(respuesta.body);
        return data.map((item) => DireccionSugerida.fromJson(item, esRegional: true)).toList();
      }
    } catch (e) {
      debugPrint('Error en búsqueda regional: $e');
    }
    return [];
  }

  // Búsqueda general
  static Future<List<DireccionSugerida>> buscarGeneral(String query, int limite) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(query)}&'
        'format=json&'
        'limit=$limite&'
        'countrycodes=cl'
      );

      final respuesta = await http.get(url, headers: {'User-Agent': _userAgent});

      if (respuesta.statusCode == 200) {
        final List<dynamic> data = json.decode(respuesta.body);
        return data.map((item) => DireccionSugerida.fromJson(item, esRegional: false)).toList();
      }
    } catch (e) {
      debugPrint('Error en búsqueda general: $e');
    }
    return [];
  }

  // Identificar región por coordenadas
  static Future<String> identificarRegion(GeoPoint posicion) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=${posicion.latitude}&'
        'lon=${posicion.longitude}&'
        'format=json&'
        'addressdetails=1&'
        'zoom=10'
      );

      final respuesta = await http.get(url, headers: {'User-Agent': _userAgent});

      if (respuesta.statusCode == 200) {
        final data = json.decode(respuesta.body);
        final address = data['address'];
        
        return address['state'] ?? 
               address['region'] ?? 
               address['county'] ?? 
               address['city'] ?? 
               address['town'] ?? 
               address['village'] ?? 
               "Región Desconocida";
      }
    } catch (e) {
      debugPrint('Error al identificar región: $e');
    }
    
    return "Región Desconocida";
  }

  // Buscar coordenadas de una dirección
  static Future<GeoPoint?> buscarCoordenadas(String direccion) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(direccion)}&format=json&limit=1&countrycodes=cl');

    final respuesta = await http.get(url, headers: {'User-Agent': _userAgent});

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

  // Calcular distancias usando fórmula Haversine
  static void calcularDistancias(List<DireccionSugerida> sugerencias, GeoPoint ubicacionUsuario) {
    if (sugerencias.isEmpty) return;
    
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

  static double _calcularDistanciaHaversine(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radio de la Tierra en km
    
    double dLat = _gradosARadianes(lat2 - lat1);
    double dLon = _gradosARadianes(lon2 - lon1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_gradosARadianes(lat1)) * math.cos(_gradosARadianes(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return R * c;
  }

  static double _gradosARadianes(double grados) {
    return grados * (math.pi / 180);
  }
}
