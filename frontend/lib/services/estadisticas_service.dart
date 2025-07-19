import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/confGlobal.dart';
import '../utils/token_manager.dart';

class EstadisticasService {
  static const String baseUrl = confGlobal.baseUrl;

  // Obtener estadísticas generales
  static Future<Map<String, dynamic>> obtenerEstadisticasGenerales() async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        throw Exception('No hay token válido');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/estadisticas/generales'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Error al obtener estadísticas generales: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerEstadisticasGenerales: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener distribución de puntuaciones
  static Future<List<Map<String, dynamic>>> obtenerDistribucionPuntuaciones() async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        throw Exception('No hay token válido');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/estadisticas/puntuaciones'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Error al obtener distribución de puntuaciones: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerDistribucionPuntuaciones: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener viajes por mes
  static Future<List<Map<String, dynamic>>> obtenerViajesPorMes() async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        throw Exception('No hay token válido');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/estadisticas/viajes-mes'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Error al obtener viajes por mes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerViajesPorMes: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener clasificación de usuarios
  static Future<List<Map<String, dynamic>>> obtenerClasificacionUsuarios() async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        throw Exception('No hay token válido');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/estadisticas/clasificacion'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Error al obtener clasificación de usuarios: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerClasificacionUsuarios: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener destinos populares
  static Future<List<Map<String, dynamic>>> obtenerDestinosPopulares() async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        throw Exception('No hay token válido');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/estadisticas/destinos'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Error al obtener destinos populares: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerDestinosPopulares: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener estadísticas de pagos
  static Future<Map<String, dynamic>> obtenerEstadisticasPagos() async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        throw Exception('No hay token válido');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/estadisticas/pagos'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Error al obtener estadísticas de pagos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerEstadisticasPagos: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener análisis avanzado
  static Future<Map<String, dynamic>> obtenerAnalisisAvanzado() async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        throw Exception('No hay token válido');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/estadisticas/analisis'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Error al obtener análisis avanzado: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerAnalisisAvanzado: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}