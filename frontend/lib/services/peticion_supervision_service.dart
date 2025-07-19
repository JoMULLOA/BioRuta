import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/confGlobal.dart';

class PeticionSupervisionService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Obtener el token JWT almacenado
  static Future<String?> _getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  // Crear encabezados con autenticación
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Crear una nueva petición de supervisión
  static Future<Map<String, dynamic>> crearPeticionSupervision({
    required String motivo,
    required String mensaje,
    String prioridad = 'media',
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'motivo': motivo,
        'mensaje': mensaje,
        'prioridad': prioridad,
      });

      final response = await http.post(
        Uri.parse('${confGlobal.baseUrl}/peticiones-supervision'),
        headers: headers,
        body: body,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        print('✅ Petición de supervisión creada exitosamente');
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        print('❌ Error al crear petición: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Error desconocido',
        };
      }
    } catch (e) {
      print('❌ Error de conexión al crear petición: $e');
      return {
        'success': false,
        'message': 'Error de conexión. Verifica tu internet.',
      };
    }
  }

  /// Obtener todas las peticiones (solo administradores)
  static Future<Map<String, dynamic>> obtenerPeticionesSupervision({
    String? estado,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '${confGlobal.baseUrl}/peticiones-supervision';
      
      if (estado != null) {
        url += '?estado=$estado';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'],
          'total': data['total'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener peticiones',
        };
      }
    } catch (e) {
      print('❌ Error al obtener peticiones: $e');
      return {
        'success': false,
        'message': 'Error de conexión. Verifica tu internet.',
      };
    }
  }

  /// Responder a una petición (solo administradores)
  static Future<Map<String, dynamic>> responderPeticionSupervision({
    required int idPeticion,
    required String accion, // 'aceptar' o 'denegar'
    String? respuesta,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'accion': accion,
        'respuesta': respuesta,
      });

      final response = await http.put(
        Uri.parse('${confGlobal.baseUrl}/peticiones-supervision/$idPeticion/responder'),
        headers: headers,
        body: body,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        print('✅ Petición respondida exitosamente');
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        print('❌ Error al responder petición: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Error desconocido',
        };
      }
    } catch (e) {
      print('❌ Error de conexión al responder petición: $e');
      return {
        'success': false,
        'message': 'Error de conexión. Verifica tu internet.',
      };
    }
  }

  /// Obtener mis peticiones (usuario actual)
  static Future<Map<String, dynamic>> obtenerMisPeticiones() async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/peticiones-supervision/mis-peticiones'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener peticiones',
        };
      }
    } catch (e) {
      print('❌ Error al obtener mis peticiones: $e');
      return {
        'success': false,
        'message': 'Error de conexión. Verifica tu internet.',
      };
    }
  }

  /// Eliminar una petición
  static Future<Map<String, dynamic>> eliminarPeticion(int idPeticion) async {
    try {
      final headers = await _getHeaders();

      final response = await http.delete(
        Uri.parse('${confGlobal.baseUrl}/peticiones-supervision/$idPeticion'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        print('✅ Petición eliminada exitosamente');
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        print('❌ Error al eliminar petición: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Error desconocido',
        };
      }
    } catch (e) {
      print('❌ Error de conexión al eliminar petición: $e');
      return {
        'success': false,
        'message': 'Error de conexión. Verifica tu internet.',
      };
    }
  }

  /// Obtener estadísticas de peticiones (solo administradores)
  static Future<Map<String, dynamic>> obtenerEstadisticasPeticiones() async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/peticiones-supervision/estadisticas'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener estadísticas',
        };
      }
    } catch (e) {
      print('❌ Error al obtener estadísticas: $e');
      return {
        'success': false,
        'message': 'Error de conexión. Verifica tu internet.',
      };
    }
  }

  /// Verificar si el usuario tiene una petición activa
  static Future<Map<String, dynamic>> verificarPeticionActiva() async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/peticiones-supervision/verificar-activa'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Error al verificar petición activa');
      }
    } catch (e) {
      print('Error verificando petición activa: $e');
      return {
        'success': false,
        'message': e.toString(),
        'tieneActiva': false,
        'data': null,
      };
    }
  }

  /// Marcar petición como solucionada (solo administradores)
  static Future<Map<String, dynamic>> marcarComoSolucionada({
    required int idPeticion,
  }) async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final response = await http.put(
        Uri.parse('${confGlobal.baseUrl}/peticiones-supervision/$idPeticion/solucionada'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Error al marcar como solucionada');
      }
    } catch (e) {
      print('Error marcando petición como solucionada: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Verificar si el usuario tiene una petición pendiente
  static Future<Map<String, dynamic>> verificarPeticionPendiente() async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/peticiones-supervision/verificar-pendiente'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Error al verificar petición pendiente');
      }
    } catch (e) {
      print('Error verificando petición pendiente: $e');
      return {
        'success': false,
        'message': e.toString(),
        'tienePendiente': false,
      };
    }
  }

  /// Obtener color según prioridad
  static String getColorPrioridad(String prioridad) {
    switch (prioridad.toLowerCase()) {
      case 'baja':
        return '#4CAF50'; // Verde
      case 'media':
        return '#FF9800'; // Naranja
      case 'alta':
        return '#F44336'; // Rojo
      case 'urgente':
        return '#9C27B0'; // Púrpura
      default:
        return '#757575'; // Gris
    }
  }

  /// Obtener icono según estado
  static String getIconoEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return '⏳';
      case 'aceptada':
        return '✅';
      case 'denegada':
        return '❌';
      default:
        return '❓';
    }
  }

  /// Obtener texto amigable para el estado
  static String getTextoEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return 'Pendiente';
      case 'aceptada':
        return 'Aceptada';
      case 'denegada':
        return 'Denegada';
      case 'solucionada':
        return 'Solucionado';
      default:
        return 'Desconocido';
    }
  }

  /// Obtener texto amigable para la prioridad
  static String getTextoPrioridad(String prioridad) {
    switch (prioridad.toLowerCase()) {
      case 'baja':
        return 'Baja';
      case 'media':
        return 'Media';
      case 'alta':
        return 'Alta';
      case 'urgente':
        return 'Urgente';
      default:
        return 'Media';
    }
  }
}