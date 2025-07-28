import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/viaje_model.dart';
import '../config/confGlobal.dart';
import '../utils/token_manager.dart'; // Agregar TokenManager para autenticación
import '../utils/date_utils.dart'; // Importar DateUtils para conversiones de zona horaria

class ApiService {
  // Configuración de la API usando confGlobal
  static String get baseUrl => confGlobal.baseUrl;
  
  static const Duration timeoutDuration = Duration(seconds: 10);
  
  /// Buscar viajes por proximidad geográfica
  static Future<List<ViajeProximidad>> buscarViajesPorProximidad({
    required double origenLat,
    required double origenLng,
    required double destinoLat,
    required double destinoLng,
    required String fechaViaje,
    required int pasajeros,
    bool soloMujeres = false, // Nuevo parámetro para filtro de género
  }) async {
    try {
      // Convertir fecha chilena (string formato "YYYY-MM-DD") a rango UTC para búsqueda en MongoDB
      final rangoFechaUtc = DateUtils.fechaChileStringARangoUtcBusqueda(fechaViaje);
      
      final queryParams = {
        'origenLat': origenLat.toString(),
        'origenLng': origenLng.toString(),
        'destinoLat': destinoLat.toString(),
        'destinoLng': destinoLng.toString(),
        'fechaViaje': rangoFechaUtc, // Usar rango UTC en lugar de fecha chilena directa
        'pasajeros': pasajeros.toString(),
        'soloMujeres': soloMujeres.toString(), // Agregar parámetro al query
      };
      
      final uri = Uri.parse('$baseUrl/viajes/buscar').replace(
        queryParameters: queryParams,
      );
      
      print('🔍 Haciendo petición a: $uri');
      
      final response = await http.get(
        uri,
        headers: await TokenManager.getAuthHeaders() ?? {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(timeoutDuration);
      
      print('📡 Respuesta HTTP: ${response.statusCode}');
      print('📄 Cuerpo de respuesta: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final data = jsonData['data'];
          final viajesList = data['viajes'] as List<dynamic>? ?? [];
          
          print('🔍 Procesando ${viajesList.length} viajes:');
          for (int i = 0; i < viajesList.length; i++) {
            final viaje = viajesList[i];
            print('  Viaje ${i + 1}:');
            print('    - _id: ${viaje['_id']}');
            print('    - id: ${viaje['id']}');
            print('    - Keys disponibles: ${viaje.keys.toList()}');
          }
          
          return viajesList
              .map((viajeJson) => ViajeProximidad.fromJson(viajeJson))
              .toList();
        } else {
          throw Exception('Respuesta de API no válida: ${jsonData['message'] ?? 'Error desconocido'}');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint no encontrado. Verifica que el backend esté ejecutándose.');
      } else if (response.statusCode == 500) {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Error interno del servidor';
        
        if (errorMessage.contains('2dsphere')) {
          throw Exception('Error de configuración de base de datos. Contacta al administrador.');
        }
        
        throw Exception('Error del servidor: $errorMessage');
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
      
    } catch (e) {
      print('❌ Error en búsqueda por proximidad: $e');
      
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Tiempo de espera agotado. Verifica tu conexión a internet.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('No se pudo conectar al servidor. Verifica que el backend esté ejecutándose.');
      } else if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Error inesperado: $e');
      }
    }
  }
  
  /// Verificar conectividad con la API
  static Future<bool> verificarConectividad() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ping'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error de conectividad: $e');
      return false;
    }
  }
}
