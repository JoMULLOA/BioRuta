/// Utilidades para el manejo de fechas y conversión de zona horaria
class DateUtils {
  /// Convierte una fecha de hora chilena (PostgreSQL) a hora local
  /// El servidor PostgreSQL ya está en hora chilena, no necesita conversión
  static DateTime utcAHoraChile(DateTime fechaChile) {
    // El servidor PostgreSQL ya está en hora chilena, retornar tal como viene
    return fechaChile;
  }

  /// Convierte una fecha UTC (MongoDB) a hora chilena
  /// MongoDB guarda en UTC, necesitamos restar 4 horas (o 3 en horario de verano)
  static DateTime utcMongoAHoraChile(DateTime fechaUtc) {
    // Chile está UTC-4 (horario estándar) o UTC-3 (horario de verano)
    // Por simplicidad, usamos UTC-3 que es el más común
    return fechaUtc.subtract(const Duration(hours: 3));
  }

  /// Convierte una fecha de hora chilena a UTC para MongoDB
  static DateTime horaChileAUtcMongo(DateTime fechaChile) {
    // Agregar 3 horas para convertir de Chile a UTC (para MongoDB)
    return fechaChile.add(const Duration(hours: 3));
  }

  /// Para búsqueda en MongoDB: Convierte fecha chilena (string formato "YYYY-MM-DD") a rango UTC
  /// Esto evita que aparezcan viajes del día anterior que en UTC parecen del día buscado
  static String fechaChileStringARangoUtcBusqueda(String fechaChileString) {
    // Parsear el string a DateTime (formato: "YYYY-MM-DD")
    final fechaChile = DateTime.parse("${fechaChileString}T00:00:00");
    
    // Crear el inicio del día en Chile (00:00)
    final inicioDiaChile = DateTime(fechaChile.year, fechaChile.month, fechaChile.day, 0, 0, 0);
    
    // Crear el fin del día en Chile (23:59:59)
    final finDiaChile = DateTime(fechaChile.year, fechaChile.month, fechaChile.day, 23, 59, 59);
    
    // Convertir ambos a UTC para la búsqueda en MongoDB
    final inicioUtc = horaChileAUtcMongo(inicioDiaChile);
    final finUtc = horaChileAUtcMongo(finDiaChile);
    
    // Formatear como rango para el backend (formato ISO 8601)
    final inicioIso = inicioUtc.toIso8601String();
    final finIso = finUtc.toIso8601String();
    
    return "$inicioIso,$finIso"; // Formato: "inicio,fin"
  }

  /// Convierte fecha chilena seleccionada por usuario a rango UTC para búsquedas en MongoDB
  /// Esto evita que aparezcan viajes del día anterior que en UTC parecen del día buscado
  static Map<String, DateTime> fechaChileARangoUtcBusqueda(DateTime fechaChile) {
    // Crear el inicio del día en Chile (00:00)
    final inicioDiaChile = DateTime(fechaChile.year, fechaChile.month, fechaChile.day, 0, 0, 0);
    
    // Crear el fin del día en Chile (23:59:59)
    final finDiaChile = DateTime(fechaChile.year, fechaChile.month, fechaChile.day, 23, 59, 59);
    
    // Convertir ambos a UTC para la búsqueda en MongoDB
    final inicioUtc = horaChileAUtcMongo(inicioDiaChile);
    final finUtc = horaChileAUtcMongo(finDiaChile);
    
    return {
      'inicio': inicioUtc,
      'fin': finUtc,
    };
  }

  /// Formatea una fecha como hora local de Chile en formato "HH:mm"
  /// (Para PostgreSQL que ya está en hora chilena)
  static String obtenerHoraChile(DateTime fechaChile) {
    // No necesita conversión porque PostgreSQL ya está en hora chilena
    return '${fechaChile.hour.toString().padLeft(2, '0')}:${fechaChile.minute.toString().padLeft(2, '0')}';
  }

  /// Formatea una fecha UTC de MongoDB como hora chilena en formato "HH:mm"
  static String obtenerHoraChileDesdeMongo(DateTime fechaUtc) {
    final fechaChile = utcMongoAHoraChile(fechaUtc);
    return '${fechaChile.hour.toString().padLeft(2, '0')}:${fechaChile.minute.toString().padLeft(2, '0')}';
  }

  /// Formatea una fecha como fecha local de Chile en formato "dd/MM/yyyy"
  /// (Para PostgreSQL que ya está en hora chilena)
  static String obtenerFechaChile(DateTime fechaChile) {
    // No necesita conversión porque PostgreSQL ya está en hora chilena
    return '${fechaChile.day}/${fechaChile.month}/${fechaChile.year}';
  }

  /// Formatea una fecha UTC de MongoDB como fecha chilena en formato "dd/MM/yyyy"
  static String obtenerFechaChileDesdeMongo(DateTime fechaUtc) {
    final fechaChile = utcMongoAHoraChile(fechaUtc);
    return '${fechaChile.day}/${fechaChile.month}/${fechaChile.year}';
  }

  /// Formatea una fecha como fecha y hora local de Chile en formato "dd/MM/yyyy HH:mm"
  /// (Para PostgreSQL que ya está en hora chilena)
  static String obtenerFechaHoraChile(DateTime fechaChile) {
    return '${obtenerFechaChile(fechaChile)} ${obtenerHoraChile(fechaChile)}';
  }

  /// Formatea una fecha UTC de MongoDB como fecha y hora chilena en formato "dd/MM/yyyy HH:mm"
  static String obtenerFechaHoraChileDesdeMongo(DateTime fechaUtc) {
    return '${obtenerFechaChileDesdeMongo(fechaUtc)} ${obtenerHoraChileDesdeMongo(fechaUtc)}';
  }

  /// Para compatibilidad con MongoDB (UTC): Convierte hora local de Chile a UTC
  static DateTime horaChileAUtc(DateTime fechaLocal) {
    // Agregar 3 horas para convertir de Chile a UTC (para MongoDB)
    return fechaLocal.add(const Duration(hours: 3));
  }

  /// Verifica si una fecha UTC de MongoDB corresponde al día seleccionado en Chile
  static bool esMismoDiaEnChile(DateTime fechaUtcMongo, DateTime fechaSeleccionadaChile) {
    final fechaMongoEnChile = utcMongoAHoraChile(fechaUtcMongo);
    
    return fechaMongoEnChile.year == fechaSeleccionadaChile.year &&
           fechaMongoEnChile.month == fechaSeleccionadaChile.month &&
           fechaMongoEnChile.day == fechaSeleccionadaChile.day;
  }
}
