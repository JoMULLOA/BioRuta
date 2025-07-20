import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/viaje_model.dart';
import '../models/marcador_viaje_model.dart';
import '../config/confGlobal.dart';
import '../utils/token_manager.dart';

class ViajeService {
  static String get baseUrl => confGlobal.baseUrl;
  static const _storage = FlutterSecureStorage();
  
  // Headers por defecto con autenticación
  static Future<Map<String, String>?> _getHeaders() async {
    return await TokenManager.getAuthHeaders(); // Usar TokenManager
  }
  
  /// Crear un nuevo viaje
  static Future<Map<String, dynamic>> crearViaje({
    required List<Map<String, dynamic>> ubicaciones,
    required String fechaHoraIda,
    String? fechaHoraVuelta,
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
      // Verificar autenticación antes de crear viaje
      if (await TokenManager.needsLogin()) {
        return {
          'success': false,
          'message': 'Sesión expirada. Por favor, inicia sesión nuevamente.'
        };
      }

      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No se pudo obtener el token de autenticación'
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/viajes/crear'),
        headers: headers,
        body: json.encode({
          'ubicaciones': ubicaciones,
          'fechaHoraIda': fechaHoraIda,
          'fechaHoraVuelta': fechaHoraVuelta,
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
          'data': data['data'], // Esto ahora puede contener viaje_ida y viaje_vuelta
          'message': data['message'] ?? 'Viaje creado exitosamente'
        };
      } else if (response.statusCode == 401) {
        // Token expirado
        await TokenManager.clearAuthData();
        return {
          'success': false,
          'message': 'Sesión expirada. Por favor, inicia sesión nuevamente.'
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
      // Verificar si necesitamos login antes de hacer la petición
      if (await TokenManager.needsLogin()) {
        throw Exception('Sesión expirada. Por favor, inicia sesión nuevamente.');
      }

      final headers = await _getHeaders();
      if (headers == null) {
        throw Exception('No se pudo obtener el token de autenticación');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/viajes/mis-viajes'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final viajesData = data['data'] as List;
        return viajesData.map((viaje) => Viaje.fromJson(viaje)).toList();
      } else if (response.statusCode == 401) {
        // Token expirado o inválido
        await TokenManager.clearAuthData();
        throw Exception('Sesión expirada. Por favor, inicia sesión nuevamente.');
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
        Uri.parse('$baseUrl/viajes/mis-viajes'),
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
  /// Eliminar un viaje por ID
  static Future<Map<String, dynamic>> eliminarViaje(String viajeId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/viajes/$viajeId/eliminar'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Viaje eliminado exitosamente'
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Error al eliminar el viaje'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// Cambiar estado de un viaje (para conductores)
  static Future<Map<String, dynamic>> cambiarEstadoViaje(String viajeId, String nuevoEstado) async {
    try {
      // Verificar si necesitamos login antes de hacer la petición
      if (await TokenManager.needsLogin()) {
        return {
          'success': false,
          'message': 'Sesión expirada. Por favor, inicia sesión nuevamente.'
        };
      }

      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No se pudo obtener el token de autenticación'
        };
      }

      final response = await http.put(
        Uri.parse('$baseUrl/viajes/$viajeId/estado'),
        headers: headers,
        body: json.encode({
          'nuevoEstado': nuevoEstado,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Estado del viaje actualizado exitosamente',
          'data': data['data']
        };
      } else if (response.statusCode == 401) {
        // Token expirado o inválido
        await TokenManager.clearAuthData();
        return {
          'success': false,
          'message': 'Sesión expirada. Por favor, inicia sesión nuevamente.'
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al cambiar el estado del viaje'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// Confirmar un pasajero en un viaje (para conductores)
  static Future<Map<String, dynamic>> confirmarPasajero(String viajeId, String usuarioRut) async {
    try {
      // Verificar si necesitamos login antes de hacer la petición
      if (await TokenManager.needsLogin()) {
        return {
          'success': false,
          'message': 'Sesión expirada. Por favor, inicia sesión nuevamente.'
        };
      }

      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No se pudo obtener el token de autenticación'
        };
      }

      final response = await http.put(
        Uri.parse('$baseUrl/viajes/$viajeId/confirmar/$usuarioRut'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Pasajero confirmado exitosamente',
          'data': data['data']
        };
      } else if (response.statusCode == 401) {
        // Token expirado o inválido
        await TokenManager.clearAuthData();
        return {
          'success': false,
          'message': 'Sesión expirada. Por favor, inicia sesión nuevamente.'
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al confirmar el pasajero'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// Abandonar un viaje (pasajero deja el viaje)
  static Future<Map<String, dynamic>> abandonarViaje(String viajeId) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No se pudo obtener el token de autenticación'
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/viajes/$viajeId/abandonar'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Has abandonado el viaje exitosamente'
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al abandonar el viaje'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// Verificar si el usuario tiene viajes activos (como conductor o pasajero)
  static Future<bool> tieneViajesActivos() async {
    try {
      // Obtener el RUT del usuario actual
      final userRut = await _storage.read(key: 'user_rut');
      if (userRut == null) {
        debugPrint('❌ No se pudo obtener el RUT del usuario actual');
        return false;
      }
      
      debugPrint('👤 RUT del usuario actual: $userRut');
      
      final viajes = await obtenerViajesUsuario();
      debugPrint('🔍 Verificando viajes activos. Total viajes: ${viajes.length}');
      
      if (viajes.isEmpty) {
        debugPrint('❌ No hay viajes para el usuario');
        return false;
      }

      // Debug: mostrar estructura de los viajes
      for (int i = 0; i < viajes.length && i < 3; i++) {
        debugPrint('🎯 Viaje $i: ${viajes[i]}');
      }
      
      final fechaActual = DateTime.now();
      debugPrint('📅 Fecha actual: $fechaActual');

      // NUEVA LÓGICA: Solo mostrar SOS si el usuario es PASAJERO (unido a un viaje)
      final viajesComoPasajero = viajes.where((viaje) {
        try {          
          // El conductor es el usuario_rut principal del viaje
          final conductorRut = viaje['usuario_rut']?.toString();
          
          debugPrint('🔍 Análisis viaje:');
          debugPrint('   - Conductor RUT: $conductorRut');
          debugPrint('   - Usuario actual RUT: $userRut');
          
          // Si el usuario es el conductor, no es pasajero
          if (conductorRut == userRut) {
            debugPrint('❌ Usuario es conductor, no pasajero');
            return false;
          }
          
          
          // Verificar si hay pasajeros en el viaje
          final pasajeros = viaje['pasajeros'];
          if (pasajeros == null || pasajeros is! List) {
            debugPrint('❌ No hay lista de pasajeros');
            return false;
          }
          
          debugPrint('   - Total pasajeros: ${pasajeros.length}');
          
          // Verificar si el usuario actual está en la lista de pasajeros
          bool esUnPasajero = false;
          String? estadoPasajero;
          
          for (var pasajero in pasajeros) {
            if (pasajero is Map<String, dynamic>) {
              final pasajeroRut = pasajero['usuario_rut']?.toString();
              final estado = pasajero['estado']?.toString().toLowerCase();
              
              debugPrint('   - Pasajero RUT: $pasajeroRut, Estado: $estado');
              
              // Comparar el RUT del pasajero con el RUT del usuario actual
              if (pasajeroRut == userRut && (estado == 'confirmado' || estado == 'pendiente')) {
                esUnPasajero = true;
                estadoPasajero = estado;
                debugPrint('✅ Usuario encontrado como pasajero con estado: $estado');
                break;
              }
            }
          }
          
          if (!esUnPasajero) {
            debugPrint('❌ Usuario actual ($userRut) no es un pasajero confirmado/pendiente en este viaje');
            return false;
          }
          
          debugPrint('✅ Es pasajero con estado: $estadoPasajero, verificando fecha...');
          
          // Verificar que el viaje sea futuro o actual
          String? fechaString;
          if (viaje.containsKey('fecha_ida')) {
            fechaString = viaje['fecha_ida'];
          } else if (viaje.containsKey('fechaHoraIda')) {
            fechaString = viaje['fechaHoraIda'];
          } else if (viaje.containsKey('fecha')) {
            fechaString = viaje['fecha'];
          }

          if (fechaString == null) {
            debugPrint('⚠️ No hay fecha, pero es pasajero confirmado -> SOS activo');
            return true;
          }

          final fechaViaje = DateTime.parse(fechaString);
          final esActivo = fechaViaje.isAfter(fechaActual.subtract(const Duration(days: 1)));
          
          debugPrint('📊 Fecha viaje: $fechaViaje, Es activo: $esActivo');
          
          return esActivo;
          
        } catch (e) {
          debugPrint('❌ Error procesando viaje: $e');
          return false;
        }
      }).toList();

      final resultado = viajesComoPasajero.isNotEmpty;
      debugPrint('🎯 RESULTADO FINAL: Mostrar SOS = $resultado (${viajesComoPasajero.length} viajes como pasajero)');
      return resultado;
    } catch (e) {
      debugPrint('💥 Error al verificar viajes activos: $e');
      return false;
    }
  }

  /// Buscar viajes en un radio específico
  static Future<List<Map<String, dynamic>>> buscarViajesEnRadio({
    required double lat,
    required double lng,
    required double radio, // en kilómetros
  }) async {
    try {
      debugPrint("🎯 Buscando viajes en radio de ${radio}km desde lat: $lat, lng: $lng");

      final headers = await _getHeaders();
      if (headers == null) {
        debugPrint("❌ No se pudieron obtener headers de autenticación");
        return [];
      }

      // Obtener fecha de hoy en formato YYYY-MM-DD
      final hoy = DateTime.now();
      final fechaHoy = "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";

      final url = Uri.parse('$baseUrl/viajes/radar');
      final body = {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radio': radio.toString(),
        'fecha': fechaHoy, // Solo viajes de hoy
      };

      debugPrint("📡 Enviando petición a: $url");
      debugPrint("📤 Body: $body");

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      debugPrint("📨 Respuesta status: ${response.statusCode}");
      debugPrint("📄 Respuesta body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> viajesData = data['data'];
          debugPrint("✅ ${viajesData.length} viajes encontrados en el radar");
          
          // Convertir a lista de Map<String, dynamic>
          return viajesData.cast<Map<String, dynamic>>();
        } else {
          debugPrint("⚠️ Respuesta sin datos de viajes");
          return [];
        }
      } else {
        debugPrint("❌ Error en la petición: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint("💥 Error buscando viajes en radar: $e");
      return [];
    }
  }
}