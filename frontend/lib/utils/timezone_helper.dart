import 'package:intl/intl.dart';

class TimezoneHelper {
  /// Offset de Chile respecto a UTC (en horas)
  /// Chile Standard Time: UTC-4 (Abril - Septiembre)
  /// Chile Summer Time: UTC-3 (Octubre - Marzo)
  static int _getChileOffsetHours() {
    final now = DateTime.now();
    final year = now.year;
    
    // Calcular fechas de cambio de horario para Chile
    // Segundo domingo de septiembre (inicia horario de verano)
    final septemberSunday = _getNthSundayOfMonth(year, 9, 2);
    // Primer domingo de abril (termina horario de verano)
    final aprilSunday = _getNthSundayOfMonth(year, 4, 1);
    
    // Verificar si estamos en horario de verano
    final isAfterSeptember = now.isAfter(septemberSunday);
    final isBeforeApril = now.isBefore(aprilSunday);
    
    // Horario de verano: octubre-marzo (UTC-3)
    // Horario estándar: abril-septiembre (UTC-4)
    if (isAfterSeptember || isBeforeApril) {
      return -3; // Horario de verano
    } else {
      return -4; // Horario estándar
    }
  }
  
  /// Obtener el n-ésimo domingo de un mes específico
  static DateTime _getNthSundayOfMonth(int year, int month, int nthSunday) {
    DateTime firstDay = DateTime(year, month, 1);
    
    // Encontrar el primer domingo del mes
    int daysToFirstSunday = (7 - firstDay.weekday) % 7;
    DateTime firstSunday = firstDay.add(Duration(days: daysToFirstSunday));
    
    // Calcular el n-ésimo domingo
    return firstSunday.add(Duration(days: (nthSunday - 1) * 7));
  }
  
  /// Convertir una fecha local a UTC considerando el timezone de Chile
  /// Esta función convierte la fecha que el usuario ve (horario chileno) a UTC
  static DateTime convertirChileAUTC(DateTime fechaChile) {
    final offsetHours = _getChileOffsetHours();
    return fechaChile.subtract(Duration(hours: offsetHours));
  }
  
  /// Convertir una fecha UTC a horario chileno
  /// Esta función convierte la fecha del backend (UTC) a horario chileno para mostrar al usuario
  static DateTime convertirUTCAChile(DateTime fechaUTC) {
    final offsetHours = _getChileOffsetHours();
    return fechaUTC.add(Duration(hours: offsetHours));
  }
  
  /// Formatear una fecha del usuario para enviar al backend
  /// Convierte la fecha seleccionada por el usuario (que está en horario chileno) a UTC para el backend
  static String formatearFechaParaBackend(DateTime fechaChile) {
    final fechaUTC = convertirChileAUTC(fechaChile);
    return DateFormat('yyyy-MM-dd').format(fechaUTC);
  }
  
  /// Formatear una fecha y hora del usuario para enviar al backend
  /// Convierte la fecha y hora seleccionada por el usuario (que está en horario chileno) a UTC para el backend
  static String formatearFechaHoraParaBackend(DateTime fechaHoraChile) {
    final fechaHoraUTC = convertirChileAUTC(fechaHoraChile);
    return fechaHoraUTC.toIso8601String();
  }
  
  /// Parsear una fecha del backend (UTC) para mostrar al usuario
  /// Convierte la fecha del backend (UTC) a horario chileno para mostrar al usuario
  static DateTime parsearFechaDelBackend(String fechaUTCString) {
    final fechaUTC = DateTime.parse(fechaUTCString);
    return convertirUTCAChile(fechaUTC);
  }
  
  /// Verificar si una fecha está en el mismo día considerando timezone chileno
  /// Útil para filtros de búsqueda por día
  static bool esMismoDiaEnChile(DateTime fecha1UTC, DateTime fecha2UTC) {
    final fecha1Chile = convertirUTCAChile(fecha1UTC);
    final fecha2Chile = convertirUTCAChile(fecha2UTC);
    
    return fecha1Chile.year == fecha2Chile.year &&
           fecha1Chile.month == fecha2Chile.month &&
           fecha1Chile.day == fecha2Chile.day;
  }
  
  /// Obtener el inicio del día en UTC para una fecha dada en Chile
  /// Útil para búsquedas de rango de fechas
  static DateTime getInicioDiaUTCParaChile(DateTime fechaChile) {
    final inicioDiaChile = DateTime(fechaChile.year, fechaChile.month, fechaChile.day);
    return convertirChileAUTC(inicioDiaChile);
  }
  
  /// Obtener el fin del día en UTC para una fecha dada en Chile
  /// Útil para búsquedas de rango de fechas
  static DateTime getFinDiaUTCParaChile(DateTime fechaChile) {
    final finDiaChile = DateTime(fechaChile.year, fechaChile.month, fechaChile.day, 23, 59, 59, 999);
    return convertirChileAUTC(finDiaChile);
  }
  
  /// Formatear una fecha para mostrar al usuario en formato legible
  static String formatearFechaParaUsuario(DateTime fechaUTC) {
    final fechaChile = convertirUTCAChile(fechaUTC);
    return DateFormat('dd/MM/yyyy HH:mm').format(fechaChile);
  }
  
  /// Formatear solo la fecha para mostrar al usuario
  static String formatearSoloFechaParaUsuario(DateTime fechaUTC) {
    final fechaChile = convertirUTCAChile(fechaUTC);
    return DateFormat('dd/MM/yyyy').format(fechaChile);
  }
  
  /// Formatear solo la hora para mostrar al usuario
  static String formatearSoloHoraParaUsuario(DateTime fechaUTC) {
    final fechaChile = convertirUTCAChile(fechaUTC);
    return DateFormat('HH:mm').format(fechaChile);
  }
  
  /// Debug: Mostrar información de timezone
  static void mostrarInfoTimezone() {
    final now = DateTime.now();
    final offsetHours = _getChileOffsetHours();
    print('🌍 Timezone Chile Info:');
    print('   Fecha actual: $now');
    print('   Offset actual: UTC$offsetHours');
    print('   Horario: ${offsetHours == -3 ? "Verano" : "Estándar"}');
  }
}
