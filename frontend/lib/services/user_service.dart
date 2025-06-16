import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class UserService {
  static String get baseUrl => ApiConfig.baseUrl;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Obtener token de autenticación
  static Future<String?> _getToken() async {
    return await _storage.read(key: 'auth_token');
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
        throw Exception('No autorizado. Token inválido o expirado');
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Error ${response.statusCode}: ${errorData['message'] ?? 'Error desconocido'}');
      }
    } catch (e) {
      print('❌ Error obteniendo vehículos: $e');
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
