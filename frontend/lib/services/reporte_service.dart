import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reporte_model.dart';
import '../config/confGlobal.dart';
import '../utils/token_manager.dart';

class ReporteService {
  static const String _baseUrl = '${confGlobal.baseUrl}/reportes';

  // Crear un nuevo reporte
  static Future<Map<String, dynamic>> crearReporte({
    required String usuarioReportado,
    required TipoReporte tipoReporte,
    required MotivoReporte motivo,
    String? descripcion,
  }) async {
    try {
      final token = await TokenManager.getValidToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No hay sesión activa',
        };
      }

      final reporte = Reporte(
        usuarioReportante: '', // Se obtendrá del token en el backend
        usuarioReportado: usuarioReportado,
        tipoReporte: tipoReporte,
        motivo: motivo,
        descripcion: descripcion,
        estado: EstadoReporte.pendiente,
        fechaCreacion: DateTime.now(),
      );

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(reporte.toCreateJson()),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Reporte enviado exitosamente',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al crear el reporte',
        };
      }
    } catch (e) {
      print('Error en crearReporte: $e');
      return {
        'success': false,
        'message': 'Error de conexión. Intenta nuevamente.',
      };
    }
  }

  // Obtener todos los reportes (solo admin)
  static Future<Map<String, dynamic>> obtenerTodosLosReportes({
    String? estado,
    String? tipoReporte,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await TokenManager.getValidToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No hay sesión activa',
        };
      }

      Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (estado != null) queryParams['estado'] = estado;
      if (tipoReporte != null) queryParams['tipoReporte'] = tipoReporte;

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        List<Reporte> reportes = [];
        if (data['data'] != null && data['data']['reportes'] != null) {
          reportes = (data['data']['reportes'] as List)
              .map((json) => Reporte.fromJson(json))
              .toList();
        }

        return {
          'success': true,
          'reportes': reportes,
          'pagination': data['data']['pagination'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener reportes',
        };
      }
    } catch (e) {
      print('Error en obtenerTodosLosReportes: $e');
      return {
        'success': false,
        'message': 'Error de conexión. Intenta nuevamente.',
      };
    }
  }

  // Actualizar estado de un reporte (solo admin)
  static Future<Map<String, dynamic>> actualizarEstadoReporte({
    required int reporteId,
    required EstadoReporte nuevoEstado,
    String? comentarioAdmin,
  }) async {
    try {
      final token = await TokenManager.getValidToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No hay sesión activa',
        };
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/$reporteId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'estado': nuevoEstado.toString().split('.').last,
          if (comentarioAdmin != null) 'comentarioAdmin': comentarioAdmin,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Reporte actualizado exitosamente',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al actualizar el reporte',
        };
      }
    } catch (e) {
      print('Error en actualizarEstadoReporte: $e');
      return {
        'success': false,
        'message': 'Error de conexión. Intenta nuevamente.',
      };
    }
  }

  // Obtener estadísticas de reportes (solo admin)
  static Future<Map<String, dynamic>> obtenerEstadisticasReportes() async {
    try {
      final token = await TokenManager.getValidToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No hay sesión activa',
        };
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/estadisticas'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'estadisticas': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener estadísticas',
        };
      }
    } catch (e) {
      print('Error en obtenerEstadisticasReportes: $e');
      return {
        'success': false,
        'message': 'Error de conexión. Intenta nuevamente.',
      };
    }
  }

  // Obtener reportes de un usuario específico (solo admin)
  static Future<Map<String, dynamic>> obtenerReportesUsuario({
    required String rutUsuario,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      print('🔍 obtenerReportesUsuario - Iniciando para usuario: $rutUsuario');
      
      final token = await TokenManager.getValidToken();
      if (token == null) {
        print('❌ obtenerReportesUsuario - No hay token válido');
        return {
          'success': false,
          'message': 'No hay sesión activa',
        };
      }

      Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$_baseUrl/usuario/$rutUsuario')
          .replace(queryParameters: queryParams);

      print('🌐 obtenerReportesUsuario - URI: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 obtenerReportesUsuario - Status Code: ${response.statusCode}');
      print('📄 obtenerReportesUsuario - Response Body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        List<Reporte> reportes = [];
        if (data['data'] != null && data['data']['reportes'] != null) {
          reportes = (data['data']['reportes'] as List)
              .map((json) => Reporte.fromJson(json))
              .toList();
        }

        print('✅ obtenerReportesUsuario - Reportes obtenidos: ${reportes.length}');

        return {
          'success': true,
          'reportes': reportes,
          'pagination': data['data']['pagination'],
          'usuario': data['data']['usuario'],
        };
      } else {
        print('❌ obtenerReportesUsuario - Error del servidor: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener reportes del usuario',
        };
      }
    } catch (e) {
      print('❌ Error en obtenerReportesUsuario: $e');
      return {
        'success': false,
        'message': 'Error de conexión. Intenta nuevamente.',
      };
    }
  }

  // Obtener reportes de un usuario específico como lista de objetos (para admin)
  static Future<List<Reporte>> obtenerReportesPorUsuario(String rutUsuario) async {
    try {
      final response = await obtenerReportesUsuario(rutUsuario: rutUsuario);
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> reportesJson = response['data']['reportes'] ?? [];
        return reportesJson.map((json) => Reporte.fromJson(json)).toList();
      } else {
        throw Exception(response['message'] ?? 'Error al obtener reportes');
      }
    } catch (e) {
      throw Exception('Error al obtener reportes del usuario: $e');
    }
  }

  // Obtener conteo de reportes por usuario
  static Future<int> obtenerConteoReportesPorUsuario(String rutUsuario) async {
    try {
      final response = await obtenerReportesUsuario(rutUsuario: rutUsuario);
      
      if (response['success'] == true && response['data'] != null) {
        return response['data']['total'] ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      return 0;
    }
  }
}
