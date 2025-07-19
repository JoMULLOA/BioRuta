import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/confGlobal.dart';

class PagoService {
  static String get baseUrl => confGlobal.baseUrl;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Crear una preferencia de pago
  static Future<Map<String, dynamic>> crearPago({
    required String viajeId,
    required double montoTotal,
    String? descripcion,
  }) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'No se encontró token de autenticación'
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/pagos/crear'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'viajeId': viajeId,
          'montoTotal': montoTotal,
          'descripcion': descripcion ?? 'Pago de viaje #$viajeId',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al crear el pago',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// Abrir MercadoPago para realizar el pago
  static Future<bool> abrirMercadoPago(String initPoint) async {
    try {
      final Uri url = Uri.parse(initPoint);
      
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error al abrir MercadoPago: $e');
      return false;
    }
  }

  /// Verificar el estado de un pago
  static Future<Map<String, dynamic>> verificarPago(String paymentId) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'No se encontró token de autenticación'
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/pagos/verificar/$paymentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al verificar el pago',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// Obtener todos los pagos del usuario
  static Future<Map<String, dynamic>> obtenerMisPagos() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'No se encontró token de autenticación'
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/pagos/mis-pagos'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener los pagos',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// Cancelar un pago pendiente
  static Future<Map<String, dynamic>> cancelarPago(int pagoId) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'No se encontró token de autenticación'
        };
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/pagos/cancelar/$pagoId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al cancelar el pago',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// Obtener el estado de un pago específico
  static Future<Map<String, dynamic>> obtenerEstadoPago(int pagoId) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'No se encontró token de autenticación'
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/pagos/estado/$pagoId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener el estado del pago',
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
