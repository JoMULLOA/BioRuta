import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../services/socket_service.dart';

class TokenManager {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Verificar si el token actual es válido
  static Future<bool> isTokenValid() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      
      if (token == null) {
        print('🔒 No hay token almacenado');
        return false;
      }

      if (JwtDecoder.isExpired(token)) {
        print('⏰ Token JWT ha expirado');
        await clearAuthData();
        return false;
      }

      print('✅ Token JWT válido');
      return true;
    } catch (e) {
      print('❌ Error verificando token: $e');
      await clearAuthData();
      return false;
    }
  }

  // Obtener el token válido para peticiones HTTP
  static Future<String?> getValidToken() async {
    final isValid = await isTokenValid();
    if (!isValid) {
      return null;
    }
    return await _storage.read(key: 'jwt_token');
  }

  // Limpiar todos los datos de autenticación
  static Future<void> clearAuthData() async {
    // IMPORTANTE: Desconectar WebSocket antes de limpiar datos
    print('🔌 Desconectando WebSocket durante clearAuthData...');
    SocketService.instance.disconnect();
    
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_rut');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    
    print('🧹 Datos de autenticación limpiados y WebSocket desconectado');
  }

  // Obtener headers de autorización válidos
  static Future<Map<String, String>?> getAuthHeaders() async {
    final token = await getValidToken();
    if (token == null) {
      return null;
    }
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Verificar si el usuario necesita hacer login
  static Future<bool> needsLogin() async {
    return !(await isTokenValid());
  }

  // Obtener información del usuario desde el token
  static Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final token = await getValidToken();
      if (token == null) return null;

      return JwtDecoder.decode(token);
    } catch (e) {
      print('❌ Error decodificando token: $e');
      return null;
    }
  }

  // Verificar tiempo restante del token
  static Future<Duration?> getTokenTimeRemaining() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return null;

      final expirationDate = JwtDecoder.getExpirationDate(token);
      final now = DateTime.now();
      
      if (expirationDate.isBefore(now)) {
        await clearAuthData();
        return null;
      }
      
      return expirationDate.difference(now);
    } catch (e) {
      print('❌ Error calculando tiempo restante: $e');
      return null;
    }
  }

  // Mostrar notificación de sesión expirada
  static void showSessionExpiredMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu sesión ha expirado. Por favor, inicia sesión nuevamente.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
