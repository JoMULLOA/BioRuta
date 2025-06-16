import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/viaje_model.dart';
import '../models/marcador_viaje_model.dart';
import '../config/api_config.dart';

class ViajeService {
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
  
  /// Crear un nuevo viaje
  static Future<Map<String, dynamic>> crearViaje({
    required List<Map<String, dynamic>> ubicaciones,
    required String fechaIda,
    required String horaIda,
    String? fechaVuelta,
    String? horaVuelta,
    required bool viajeIdaYVuelta,
    required int maxPasajeros,
    required bool soloMujeres,
    required String flexibilidadSalida,
    required double precio,
    required int plazasDisponibles,
    String? comentarios,
    required String vehiculoPatente,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/viajes/crear'),
        headers: await _getHeaders(),
        body: json.encode({
          'ubicaciones': ubicaciones,
          'fechaIda': fechaIda,
          'horaIda': horaIda,
          'fechaVuelta': fechaVuelta,
          'horaVuelta': horaVuelta,
          'viajeIdaYVuelta': viajeIdaYVuelta,
          'maxPasajeros': maxPasajeros,
          'soloMujeres': soloMujeres,
          'flexibilidadSalida': flexibilidadSalida,
          'precio': precio,
          'plazasDisponibles': plazasDisponibles,
          'comentarios': comentarios,
          'vehiculoPatente': vehiculoPatente,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'viaje': data['data'],
          'message': data['message'] ?? 'Viaje creado exitosamente'
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al crear el viaje'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }
  
  /// Buscar viajes por proximidad (radio de 500m)
  static Future<List<Viaje>> buscarViajesPorProximidad({
    required double origenLat,
    required double origenLon,
    required double destinoLat,
    required double destinoLon,
    required String fecha,
    int pasajeros = 1,
    double radio = 0.5, // 500 metros
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/viajes/buscar-proximidad').replace(
          queryParameters: {
            'origen_lat': origenLat.toString(),
            'origen_lon': origenLon.toString(),
            'destino_lat': destinoLat.toString(),
            'destino_lon': destinoLon.toString(),
            'fecha': fecha,
            'pasajeros': pasajeros.toString(),
            'radio': radio.toString(),
          },
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final viajesData = data['data']['viajes'] as List;
        return viajesData.map((viaje) => Viaje.fromJson(viaje)).toList();
      } else {
        throw Exception('Error al buscar viajes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener marcadores para el mapa
  static Future<List<MarcadorViaje>> obtenerMarcadoresViajes({
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (fechaDesde != null) queryParams['fecha_desde'] = fechaDesde;
      if (fechaHasta != null) queryParams['fecha_hasta'] = fechaHasta;

      final response = await http.get(
        Uri.parse('$baseUrl/viajes/mapa').replace(
          queryParameters: queryParams.isEmpty ? null : queryParams,
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final marcadoresData = data['data']['marcadores'] as List;
        return marcadoresData
            .map((marcador) => MarcadorViaje.fromJson(marcador))
            .toList();
      } else {
        throw Exception('Error al obtener marcadores: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Unirse a un viaje
  static Future<Map<String, dynamic>> unirseAViaje(
    String viajeId, {
    int pasajeros = 1,
    String? mensaje,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/viajes/$viajeId/unirse'),
        headers: await _getHeaders(),
        body: json.encode({
          'pasajeros_solicitados': pasajeros,
          if (mensaje != null && mensaje.isNotEmpty) 'mensaje': mensaje,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Solicitud enviada exitosamente'
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al unirse al viaje'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// Obtener viajes del usuario actual
  static Future<List<Viaje>> obtenerMisViajes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/viajes/mis-viajes'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final viajesData = data['data'] as List;
        return viajesData.map((viaje) => Viaje.fromJson(viaje)).toList();
      } else {
        throw Exception('Error al obtener mis viajes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener lista de vehículos del usuario para crear viaje
  static Future<List<Map<String, dynamic>>> obtenerVehiculosUsuario() async {
    try {
      // Este endpoint debería existir en el backend para usuarios
      final response = await http.get(
        Uri.parse('$baseUrl/users/mis-vehiculos'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Error al obtener vehículos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener viajes del usuario (creados y a los que se ha unido)
  static Future<List<Map<String, dynamic>>> obtenerViajesUsuario() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/viajes/usuario'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Error al obtener viajes del usuario: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
