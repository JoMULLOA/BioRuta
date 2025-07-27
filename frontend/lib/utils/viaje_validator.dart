import 'dart:math';

/// Utility class para validar viajes y calcular duraciones estimadas
class ViajeValidator {
  
  /// Calcular duración estimada del viaje basada en distancia por carretera y tipo de terreno
  static Duration calcularDuracionEstimada(double distanciaKm) {
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
    
    // Tiempo = distancia / velocidad
    final horas = distanciaKm / velocidadPromedio;
    return Duration(minutes: (horas * 60).round());
  }

  /// Calcular distancia por carretera usando factor de corrección (no línea recta)
  /// Similar a calcularDistanciaKmConFactor del backend
  static double calcularDistanciaCarretera(double lat1, double lon1, double lat2, double lon2) {
    // Primero calcular distancia en línea recta usando Haversine
    double distanciaLineal = calcularDistancia(lat1, lon1, lat2, lon2);
    
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

  /// Calcular distancia entre dos puntos geográficos usando la fórmula de Haversine
  static double calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    const double radioTierra = 6371; // Radio de la Tierra en km
    
    // Convertir grados a radianes
    final dLat = _gradosARadianes(lat2 - lat1);
    final dLon = _gradosARadianes(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_gradosARadianes(lat1)) *
        cos(_gradosARadianes(lat2)) *
        sin(dLon / 2) *
        sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return radioTierra * c;
  }

  /// Convertir grados a radianes
  static double _gradosARadianes(double grados) {
    return grados * (pi / 180);
  }

  /// Verificar si una fecha/hora ya pasó considerando zona horaria chilena
  static bool yaEsPasada(DateTime fechaUTC) {
    // Convertir UTC a hora chilena (UTC-4)
    final fechaChile = fechaUTC.subtract(const Duration(hours: 4));
    final ahoraChile = DateTime.now();
    
    return fechaChile.isBefore(ahoraChile);
  }

  /// Verificar si dos viajes se solapan en tiempo
  static bool viajesSeSolapan({
    required DateTime inicioViaje1,
    required Duration duracionViaje1,
    required DateTime inicioViaje2,
    required Duration duracionViaje2,
  }) {
    final finViaje1 = inicioViaje1.add(duracionViaje1);
    final finViaje2 = inicioViaje2.add(duracionViaje2);
    
    // Viajes se solapan si uno comienza antes de que termine el otro
    return (inicioViaje1.isBefore(finViaje2) && finViaje1.isAfter(inicioViaje2));
  }

  /// Verificar si el usuario puede publicar un viaje en una fecha específica
  /// considerando viajes activos y sus duraciones
  static bool puedePublicarViaje({
    required DateTime nuevaFecha,
    required double distanciaKm,
    required List<Map<String, dynamic>> viajesActivos,
  }) {
    final duracionNuevoViaje = calcularDuracionEstimada(distanciaKm);
    
    for (final viaje in viajesActivos) {
      // Convertir fecha UTC de MongoDB a hora chilena (UTC-4)
      final fechaUtc = DateTime.parse(viaje['fecha_ida']);
      final fechaViajeActivo = fechaUtc.subtract(const Duration(hours: 4));
      
      final origenLat = viaje['origen']['ubicacion']['coordinates'][1];
      final origenLng = viaje['origen']['ubicacion']['coordinates'][0];
      final destinoLat = viaje['destino']['ubicacion']['coordinates'][1];
      final destinoLng = viaje['destino']['ubicacion']['coordinates'][0];
      
      // Usar distancia por carretera en lugar de línea recta
      final distanciaViajeActivo = calcularDistanciaCarretera(origenLat, origenLng, destinoLat, destinoLng);
      final duracionViajeActivo = calcularDuracionEstimada(distanciaViajeActivo);
      
      if (viajesSeSolapan(
        inicioViaje1: nuevaFecha,
        duracionViaje1: duracionNuevoViaje,
        inicioViaje2: fechaViajeActivo,
        duracionViaje2: duracionViajeActivo,
      )) {
        return false;
      }
    }
    
    return true;
  }

  /// Obtener el próximo tiempo disponible para publicar un viaje
  static DateTime? obtenerProximoTiempoDisponible({
    required double distanciaKm,
    required List<Map<String, dynamic>> viajesActivos,
  }) {
    if (viajesActivos.isEmpty) return DateTime.now().add(const Duration(minutes: 30));
    
    DateTime? proximoTiempo;
    
    for (final viaje in viajesActivos) {
      // Convertir fecha UTC de MongoDB a hora chilena (UTC-4)
      final fechaUtc = DateTime.parse(viaje['fecha_ida']);
      final fechaViajeActivo = fechaUtc.subtract(const Duration(hours: 4));
      final origenLat = viaje['origen']['ubicacion']['coordinates'][1];
      final origenLng = viaje['origen']['ubicacion']['coordinates'][0];
      final destinoLat = viaje['destino']['ubicacion']['coordinates'][1];
      final destinoLng = viaje['destino']['ubicacion']['coordinates'][0];
      
      // Usar distancia por carretera para cálculo más preciso
      final distanciaViajeActivo = calcularDistanciaCarretera(origenLat, origenLng, destinoLat, destinoLng);
      final duracionViajeActivo = calcularDuracionEstimada(distanciaViajeActivo);
      
      final finViajeActivo = fechaViajeActivo.add(duracionViajeActivo);
      
      if (proximoTiempo == null || finViajeActivo.isAfter(proximoTiempo)) {
        proximoTiempo = finViajeActivo;
      }
    }
    
    return proximoTiempo;
  }

  /// Formatear duración en texto legible
  static String formatearDuracion(Duration duracion) {
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes % 60;
    
    if (horas == 0) {
      return '$minutos minutos';
    } else if (minutos == 0) {
      return '$horas ${horas == 1 ? 'hora' : 'horas'}';
    } else {
      return '$horas ${horas == 1 ? 'hora' : 'horas'} y $minutos minutos';
    }
  }
}
