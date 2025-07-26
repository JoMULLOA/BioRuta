import 'dart:math';

/// Utility class para validar viajes y calcular duraciones estimadas
class ViajeValidator {
  
  /// Calcular duración estimada del viaje basada en distancia
  /// 1 hora cada 90 kilómetros
  static Duration calcularDuracionEstimada(double distanciaKm) {
    // 1 hora por cada 90km
    final horas = distanciaKm / 90.0;
    return Duration(minutes: (horas * 60).round());
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
      final fechaViajeActivo = DateTime.parse(viaje['fecha_ida']);
      final origenLat = viaje['origen']['ubicacion']['coordinates'][1];
      final origenLng = viaje['origen']['ubicacion']['coordinates'][0];
      final destinoLat = viaje['destino']['ubicacion']['coordinates'][1];
      final destinoLng = viaje['destino']['ubicacion']['coordinates'][0];
      
      final distanciaViajeActivo = calcularDistancia(origenLat, origenLng, destinoLat, destinoLng);
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
      final fechaViajeActivo = DateTime.parse(viaje['fecha_ida']);
      final origenLat = viaje['origen']['ubicacion']['coordinates'][1];
      final origenLng = viaje['origen']['ubicacion']['coordinates'][0];
      final destinoLat = viaje['destino']['ubicacion']['coordinates'][1];
      final destinoLng = viaje['destino']['ubicacion']['coordinates'][0];
      
      final distanciaViajeActivo = calcularDistancia(origenLat, origenLng, destinoLat, destinoLng);
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
