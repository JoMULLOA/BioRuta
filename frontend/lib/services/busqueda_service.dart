import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import '../models/direccion_sugerida.dart';

class BusquedaService {
  static const String _userAgent = 'flutter_bioruta_app';

  // Búsqueda con región específica
  static Future<List<DireccionSugerida>> buscarConRegion(String query, String region, {bool? esOrigen}) async {
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
        return data.map((item) => DireccionSugerida.fromJson(item, esRegional: true, esOrigen: esOrigen)).toList();
      }
    } catch (e) {
      debugPrint('Error en búsqueda regional: $e');
    }
    return [];
  }

  // Búsqueda general
  static Future<List<DireccionSugerida>> buscarGeneral(String query, int limite, {bool? esOrigen}) async {
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
        return data.map((item) => DireccionSugerida.fromJson(item, esRegional: false, esOrigen: esOrigen)).toList();
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

  // Calcular solo tiempo estimado (no distancias) para destinos
  static void calcularDistancias(List<DireccionSugerida> sugerencias, GeoPoint ubicacionUsuario) {
    if (sugerencias.isEmpty) return;
    
    for (var sugerencia in sugerencias) {
      // No calcular ni mostrar distancia
      sugerencia.distancia = 0.0;
      
      // Solo calcular tiempo estimado si es para seleccionar DESTINO
      if (sugerencia.esOrigen == false) {
        // Es destino: calcular tiempo estimado del viaje
        double distanciaCarretera = _calcularDistanciaConFactor(
          ubicacionUsuario.latitude,
          ubicacionUsuario.longitude,
          sugerencia.lat,
          sugerencia.lon,
        );
        int tiempoMinutos = _calcularTiempoEstimado(distanciaCarretera);
        sugerencia.tiempoEstimado = tiempoMinutos;
      } else {
        // Es origen: no calcular tiempo
        sugerencia.tiempoEstimado = 0;
      }
    }
  }

  // Calcular solo tiempo estimado para destino con origen específico
  static void calcularDistanciasConOrigen(
    List<DireccionSugerida> sugerencias, 
    GeoPoint ubicacionUsuario,
    DireccionSugerida? origenSeleccionado
  ) {
    if (sugerencias.isEmpty) return;
    
    for (var sugerencia in sugerencias) {
      // No calcular ni mostrar distancia
      sugerencia.distancia = 0.0;
      
      // Solo calcular tiempo estimado si es para seleccionar DESTINO Y tenemos origen
      if (sugerencia.esOrigen == false && origenSeleccionado != null) {
        // Es destino: calcular tiempo estimado de la ruta origen→destino
        double distanciaRuta = _calcularDistanciaConFactor(
          origenSeleccionado.lat,
          origenSeleccionado.lon,
          sugerencia.lat,
          sugerencia.lon,
        );
        int tiempoMinutos = _calcularTiempoEstimado(distanciaRuta);
        sugerencia.tiempoEstimado = tiempoMinutos;
      } else {
        // Es origen: no calcular tiempo
        sugerencia.tiempoEstimado = 0;
      }
    }
  }

  /// Calcular distancia por carretera usando factor de corrección sobre Haversine
  /// Similar a calcularDistanciaKmConFactor del backend
  static double _calcularDistanciaConFactor(double lat1, double lon1, double lat2, double lon2) {
    // Primero calcular distancia en línea recta
    double distanciaLineal = _calcularDistanciaHaversine(lat1, lon1, lat2, lon2);
    
    // Factor de corrección según distancia (basado en estadísticas reales de Chile)
    double factor = 1.2; // 20% más por defecto
    
    if (distanciaLineal < 5) {
      factor = 1.6; // Ciudades: +60% (muchas vueltas)
    } else if (distanciaLineal < 15) {
      factor = 1.4; // Urbano: +40%
    } else if (distanciaLineal < 50) {
      factor = 1.3; // Regional: +30%
    } else if (distanciaLineal < 200) {
      factor = 1.2; // Interprovincial: +20%
    } else {
      factor = 1.15; // Larga distancia: +15% (autopistas más directas)
    }
    
    return distanciaLineal * factor;
  }

  /// Calcular tiempo estimado de viaje en minutos
  static int _calcularTiempoEstimado(double distanciaKm) {
    // Velocidades promedio más realistas según tipo de ruta en Chile
    double velocidadPromedio;
    
    if (distanciaKm < 3) {
      velocidadPromedio = 15; // Centro ciudad: 15 km/h (muy congestionado)
    } else if (distanciaKm < 8) {
      velocidadPromedio = 20; // Ciudad: 20 km/h (tráfico, semáforos)
    } else if (distanciaKm < 20) {
      velocidadPromedio = 30; // Urbano/suburbano: 30 km/h
    } else if (distanciaKm < 50) {
      velocidadPromedio = 55; // Regional: 55 km/h (carreteras secundarias)
    } else if (distanciaKm < 150) {
      velocidadPromedio = 75; // Interprovincial: 75 km/h (rutas principales)
    } else {
      velocidadPromedio = 85; // Larga distancia: 85 km/h (autopistas)
    }
    
    // Tiempo = distancia / velocidad, convertido a minutos
    double tiempoHoras = distanciaKm / velocidadPromedio;
    return (tiempoHoras * 60).round();
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
