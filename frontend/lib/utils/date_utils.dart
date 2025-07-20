/// Utilidades para el manejo de fechas y conversión de zona horaria
class DateUtils {
  /// Convierte una fecha UTC a hora local de Chile (UTC-4)
  /// Chile está en UTC-4 (hora estándar) y UTC-3 (horario de verano)
  /// Por simplicidad, usaremos UTC-4 que es la zona horaria estándar
  static DateTime utcAHoraChile(DateTime fechaUtc) {
    // Chile está en UTC-4 (zona horaria estándar)
    return fechaUtc.subtract(const Duration(hours: 4));
  }

  /// Formatea una fecha UTC como hora local de Chile en formato "HH:mm"
  static String obtenerHoraChile(DateTime fechaUtc) {
    final fechaChile = utcAHoraChile(fechaUtc);
    return '${fechaChile.hour.toString().padLeft(2, '0')}:${fechaChile.minute.toString().padLeft(2, '0')}';
  }

  /// Formatea una fecha UTC como fecha local de Chile en formato "dd/MM/yyyy"
  static String obtenerFechaChile(DateTime fechaUtc) {
    final fechaChile = utcAHoraChile(fechaUtc);
    return '${fechaChile.day}/${fechaChile.month}/${fechaChile.year}';
  }

  /// Formatea una fecha UTC como fecha y hora local de Chile en formato "dd/MM/yyyy HH:mm"
  static String obtenerFechaHoraChile(DateTime fechaUtc) {
    return '${obtenerFechaChile(fechaUtc)} ${obtenerHoraChile(fechaUtc)}';
  }

  /// Convierte una fecha de hora local de Chile a UTC para enviar al backend
  static DateTime horaChileAUtc(DateTime fechaLocal) {
    // Agregar 4 horas para convertir de Chile a UTC
    return fechaLocal.add(const Duration(hours: 4));
  }
}
