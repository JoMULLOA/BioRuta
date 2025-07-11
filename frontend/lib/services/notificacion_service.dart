import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/confGlobal.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificacionService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String?> _getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Obtener el número de notificaciones pendientes
  static Future<int> obtenerNumeroNotificacionesPendientes() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/notificaciones/pendientes'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return (data['data'] as List).length;
        }
      }
      return 0;
    } catch (e) {
      print('ERROR: Error al obtener notificaciones pendientes: $e');
      return 0;
    }
  }

  // Obtener todas las notificaciones pendientes
  static Future<Map<String, dynamic>> obtenerNotificacionesPendientes() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/notificaciones/pendientes'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener notificaciones',
          'data': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
        'data': [],
      };
    }
  }

  // Responder a una solicitud de viaje (aceptar o rechazar)
  static Future<Map<String, dynamic>> responderSolicitudViaje({
    required String notificacionId,
    required bool aceptar,
  }) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('${confGlobal.baseUrl}/notificaciones/$notificacionId/responder'),
        headers: headers,
        body: jsonEncode({
          'aceptar': aceptar,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? (aceptar ? 'Solicitud aceptada' : 'Solicitud rechazada'),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al procesar la respuesta',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  // Marcar notificación como leída
  static Future<Map<String, dynamic>> marcarComoLeida(String notificacionId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.patch(
        Uri.parse('${confGlobal.baseUrl}/notificaciones/$notificacionId/leer'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Notificación marcada como leída',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al marcar como leída',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }
}
