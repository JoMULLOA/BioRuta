/// Utilidades para el manejo de fechas y conversión de zona horaria
class DateUtils {
  /// Convierte una fecha de hora chilena (PostgreSQL) a hora local
  /// El servidor PostgreSQL ya está en hora chilena, no necesita conversión
  static DateTime utcAHoraChile(DateTime fechaChile) {
    // El servidor PostgreSQL ya está en hora chilena, retornar tal como viene
    return fechaChile;
  }

  /// Formatea una fecha como hora local de Chile en formato "HH:mm"
  /// (Para PostgreSQL que ya está en hora chilena)
  static String obtenerHoraChile(DateTime fechaChile) {
    // No necesita conversión porque PostgreSQL ya está en hora chilena
    return '${fechaChile.hour.toString().padLeft(2, '0')}:${fechaChile.minute.toString().padLeft(2, '0')}';
  }

  /// Formatea una fecha como fecha local de Chile en formato "dd/MM/yyyy"
  /// (Para PostgreSQL que ya está en hora chilena)
  static String obtenerFechaChile(DateTime fechaChile) {
    // No necesita conversión porque PostgreSQL ya está en hora chilena
    return '${fechaChile.day}/${fechaChile.month}/${fechaChile.year}';
  }

  /// Formatea una fecha como fecha y hora local de Chile en formato "dd/MM/yyyy HH:mm"
  /// (Para PostgreSQL que ya está en hora chilena)
  static String obtenerFechaHoraChile(DateTime fechaChile) {
    return '${obtenerFechaChile(fechaChile)} ${obtenerHoraChile(fechaChile)}';
  }

  /// Para compatibilidad con MongoDB (UTC): Convierte hora local de Chile a UTC
  static DateTime horaChileAUtc(DateTime fechaLocal) {
    // Agregar 4 horas para convertir de Chile a UTC (solo para MongoDB)
    return fechaLocal.add(const Duration(hours: 4));
  }
}
