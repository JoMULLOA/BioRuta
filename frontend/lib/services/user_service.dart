import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/token_manager.dart';

class UserService {
  static String get baseUrl => ApiConfig.baseUrl;
  
  // Obtener token de autenticación
  static Future<String?> _getToken() async {
    return await TokenManager.getValidToken();
  }
  
  // Headers por defecto con autenticación
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  /// Obtener vehículos del usuario autenticado
  static Future<List<Map<String, dynamic>>> obtenerMisVehiculos() async {
    try {
      print('🚗 Solicitando vehículos del usuario...');
      
      // Verificar que tengamos un token válido antes de hacer la petición
      final token = await _getToken();
      if (token == null) {
        throw Exception('No hay token de autenticación válido');
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/users/mis-vehiculos'),
        headers: await _getHeaders(),
      );

      print('🚗 Response status: ${response.statusCode}');
      print('🚗 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final vehiculos = List<Map<String, dynamic>>.from(data['data']);
        print('✅ Vehículos obtenidos: ${vehiculos.length}');
        return vehiculos;
      } else if (response.statusCode == 401) {
        // Token expirado o inválido, limpiar datos de autenticación
        await TokenManager.clearAuthData();
        throw Exception('Sesión expirada. Por favor, inicia sesión nuevamente');
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Error ${response.statusCode}: ${errorData['message'] ?? 'Error desconocido'}');
      }
    } catch (e) {
      print('❌ Error obteniendo vehículos: $e');
      
      // Si el error contiene información sobre token expirado, limpiamos los datos
      if (e.toString().contains('expirado') || e.toString().contains('expired') || e.toString().contains('401')) {
        await TokenManager.clearAuthData();
      }
      
      throw Exception('Error de conexión: $e');
    }
  }
  
  /// Obtener información del usuario actual
  static Future<Map<String, dynamic>?> obtenerPerfilUsuario() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/detail/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        return null;
      }
    } catch (e) {
      print('Error obteniendo perfil de usuario: $e');
      return null;
    }
  }
}
