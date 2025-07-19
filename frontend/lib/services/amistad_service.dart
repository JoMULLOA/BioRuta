import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/confGlobal.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AmistadService {
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

  // Enviar solicitud de amistad
  static Future<Map<String, dynamic>> enviarSolicitudAmistad({
    required String rutReceptor,
    String? mensaje,
  }) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('${confGlobal.baseUrl}/amistad/solicitud'),
        headers: headers,
        body: jsonEncode({
          'rutReceptor': rutReceptor,
          'mensaje': mensaje,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Solicitud enviada correctamente',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al enviar solicitud',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  // Responder solicitud de amistad
  static Future<Map<String, dynamic>> responderSolicitudAmistad({
    required int idSolicitud,
    required String respuesta, // "aceptada" o "rechazada"
  }) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.put(
        Uri.parse('${confGlobal.baseUrl}/amistad/solicitud/$idSolicitud'),
        headers: headers,
        body: jsonEncode({
          'respuesta': respuesta,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Solicitud respondida correctamente',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al responder solicitud',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  // Obtener solicitudes pendientes
  static Future<Map<String, dynamic>> obtenerSolicitudesPendientes() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/amistad/solicitudes-pendientes'),
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
          'message': data['message'] ?? 'Error al obtener solicitudes',
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

  // Obtener lista de amigos
  static Future<Map<String, dynamic>> obtenerAmigos() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/amistad/mis-amigos'),
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
          'message': data['message'] ?? 'Error al obtener amigos',
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

  // Eliminar amistad
  static Future<Map<String, dynamic>> eliminarAmistad(String rutAmigo) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.delete(
        Uri.parse('${confGlobal.baseUrl}/amistad/eliminar/$rutAmigo'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Amistad eliminada correctamente',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al eliminar amistad',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  // Obtener notificaciones
  static Future<Map<String, dynamic>> obtenerNotificaciones() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/notificaciones'),
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

  // Contar notificaciones pendientes
  static Future<Map<String, dynamic>> contarNotificacionesPendientes() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/notificaciones/count'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'count': data['data']['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'count': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'count': 0,
      };
    }
  }
}
