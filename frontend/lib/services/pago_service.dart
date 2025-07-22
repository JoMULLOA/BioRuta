import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/confGlobal.dart';
import '../utils/token_manager.dart';

class PagoService {
  static const String baseUrl = confGlobal.baseUrl;

  /// Crear un nuevo pago básico
  static Future<Map<String, dynamic>> crearPago({
    required String viajeId,
    required double montoTotal,
    required String descripcion,
  }) async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No hay token de autenticación válido'
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/pago/crear'),
        headers: headers,
        body: json.encode({
          'viajeId': viajeId,
          'montoTotal': montoTotal,
          'descripcion': descripcion,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
          'message': responseData['message'] ?? 'Pago creado exitosamente'
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Error al crear pago'
        };
      }
    } catch (e) {
      print('Error en crearPago: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// Procesar un pago básico
  static Future<Map<String, dynamic>> procesarPagoBasico({
    required String viajeId,
    required double montoTotal,
    required String descripcion,
  }) async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No hay token de autenticación válido'
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/pago/procesar-basico'),
        headers: headers,
        body: json.encode({
          'viajeId': viajeId,
          'montoTotal': montoTotal,
          'descripcion': descripcion,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
          'message': responseData['message'] ?? 'Pago procesado exitosamente'
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Error al procesar pago'
        };
      }
    } catch (e) {
      print('Error en procesarPagoBasico: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// Verificar el estado de un pago
  static Future<Map<String, dynamic>> verificarPago(String pagoId) async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No hay token de autenticación válido'
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/pago/verificar/$pagoId'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Error al verificar pago'
        };
      }
    } catch (e) {
      print('Error en verificarPago: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// Actualizar estado de un pago
  static Future<Map<String, dynamic>> actualizarEstadoPago(
    String pagoId,
    String nuevoEstado,
  ) async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No hay token de autenticación válido'
        };
      }

      final response = await http.put(
        Uri.parse('$baseUrl/pago/actualizar/$pagoId'),
        headers: headers,
        body: json.encode({
          'estado': nuevoEstado,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
          'message': responseData['message'] ?? 'Estado actualizado exitosamente'
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Error al actualizar estado'
        };
      }
    } catch (e) {
      print('Error en actualizarEstadoPago: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// Obtener historial de pagos del usuario
  static Future<Map<String, dynamic>> obtenerMisPagos() async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No hay token de autenticación válido'
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/pago/mis-pagos'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData['data'] ?? []
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Error al obtener pagos'
        };
      }
    } catch (e) {
      print('Error en obtenerMisPagos: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// Cancelar un pago
  static Future<Map<String, dynamic>> cancelarPago(int pagoId) async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No hay token de autenticación válido'
        };
      }

      final response = await http.put(
        Uri.parse('$baseUrl/pago/cancelar/$pagoId'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
          'message': responseData['message'] ?? 'Pago cancelado exitosamente'
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Error al cancelar pago'
        };
      }
    } catch (e) {
      print('Error en cancelarPago: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// Verificar pagos pendientes (para el historial)
  static Future<Map<String, dynamic>> verificarPagosPendientes() async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No hay token de autenticación válido'
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/pago/verificar-pendientes'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
          'message': responseData['message'] ?? 'Verificación completada'
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Error al verificar pagos pendientes'
        };
      }
    } catch (e) {
      print('Error en verificarPagosPendientes: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }
}
