import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/viaje_model.dart';
import '../models/marcador_viaje_model.dart';
import '../config/confGlobal.dart';
import '../utils/token_manager.dart';
import '../utils/viaje_validator.dart';

class ViajeService {
  static String get baseUrl => confGlobal.baseUrl;
  static const _storage = FlutterSecureStorage();
  
  // Headers por defecto con autenticación
  static Future<Map<String, String>?> _getHeaders() async {
    return await TokenManager.getAuthHeaders(); // Usar TokenManager
  }
  
  /// Validar si se puede publicar un viaje en una fecha específica
  static Future<Map<String, dynamic>> validarPublicacionViaje({
    required DateTime fechaHoraIda,
    DateTime? fechaHoraVuelta,
    required double origenLat,
    required double origenLng,
    required double destinoLat,
    required double destinoLng,
  }) async {
    try {
      // Calcular distancia del nuevo viaje por carretera (no línea recta)
      final distanciaKm = ViajeValidator.calcularDistanciaCarretera(origenLat, origenLng, destinoLat, destinoLng);
      
      // Obtener viajes activos del usuario
      final viajesActivos = await _obtenerViajesActivosUsuario();
      
      // Validar viaje de ida
      final puedePublicarIda = ViajeValidator.puedePublicarViaje(
        nuevaFecha: fechaHoraIda,
        distanciaKm: distanciaKm,
        viajesActivos: viajesActivos,
      );
      
      if (!puedePublicarIda) {
        final proximoTiempo = ViajeValidator.obtenerProximoTiempoDisponible(
          distanciaKm: distanciaKm,
          viajesActivos: viajesActivos,
        );
        
        final duracionEstimada = ViajeValidator.calcularDuracionEstimada(distanciaKm);
        
        return {
          'success': false,
          'message': 'No puedes publicar este viaje porque se solapa con un viaje activo. '
                     'Duración estimada: ${ViajeValidator.formatearDuracion(duracionEstimada)}',
          'proximoTiempoDisponible': proximoTiempo,
          'duracionEstimada': duracionEstimada,
        };
      }
      
      // Si hay viaje de vuelta, validarlo también
      if (fechaHoraVuelta != null) {
        final puedePublicarVuelta = ViajeValidator.puedePublicarViaje(
          nuevaFecha: fechaHoraVuelta,
          distanciaKm: distanciaKm,
          viajesActivos: [...viajesActivos, {
            // Convertir la fecha de ida a UTC para que sea consistente con los viajes activos de MongoDB
            'fecha_ida': fechaHoraIda.add(const Duration(hours: 4)).toIso8601String(),
            'origen': {'ubicacion': {'coordinates': [origenLng, origenLat]}},
            'destino': {'ubicacion': {'coordinates': [destinoLng, destinoLat]}},
          }], // Incluir el viaje de ida en la validación
        );
        
        if (!puedePublicarVuelta) {
          final duracionEstimada = ViajeValidator.calcularDuracionEstimada(distanciaKm);
          return {
            'success': false,
            'message': 'El viaje de vuelta se solapa con otros viajes. '
                       'Duración estimada: ${ViajeValidator.formatearDuracion(duracionEstimada)}',
            'duracionEstimada': duracionEstimada,
          };
        }
      }
      
      return {
        'success': true,
        'message': 'Viaje válido para publicar',
        'duracionEstimada': ViajeValidator.calcularDuracionEstimada(distanciaKm),
        'distanciaKm': distanciaKm,
      };
      
    } catch (e) {
      return {
        'success': false,
        'message': 'Error validando viaje: $e',
      };
    }
  }
  
  /// Validar publicación de viaje con validación inteligente de tiempo de traslado
  static Future<Map<String, dynamic>> validarPublicacionViajeConTiempo({
    required DateTime fechaHoraIda,
    DateTime? fechaHoraVuelta,
    required double origenLat,
    required double origenLng,
    required double destinoLat,
    required double destinoLng,
  }) async {
    try {
      // Validar viaje de ida
      final validacionIda = await ViajeValidator.validarViajeConTiempo(
        fechaHoraIda: fechaHoraIda,
        origenLat: origenLat,
        origenLng: origenLng,
        destinoLat: destinoLat,
        destinoLng: destinoLng,
      );
      
      if (!validacionIda['success']) {
        return validacionIda;
      }
      
      // Si hay viaje de vuelta, validarlo también
      if (fechaHoraVuelta != null) {
        final validacionVuelta = await ViajeValidator.validarViajeConTiempo(
          fechaHoraIda: fechaHoraVuelta,
          origenLat: destinoLat, // Origen de vuelta es destino de ida
          origenLng: destinoLng,
          destinoLat: origenLat, // Destino de vuelta es origen de ida
          destinoLng: origenLng,
        );
        
        if (!validacionVuelta['success']) {
          return {
            'success': false,
            'message': 'Conflicto con viaje de vuelta: ${validacionVuelta['message']}',
            'tipoConflicto': validacionVuelta['tipoConflicto'],
          };
        }
      }
      
      return {
        'success': true,
        'message': 'Viajes válidos - no hay conflictos de tiempo',
      };
      
    } catch (e) {
      return {
        'success': false,
        'message': 'Error validando viajes: $e',
      };
    }
  }
  
  /// Obtener viajes activos del usuario para validaciones (método público)
  static Future<List<Map<String, dynamic>>> obtenerViajesActivosUsuario() async {
    return await _obtenerViajesActivosUsuario();
  }
  
  /// Obtener viajes activos del usuario para validaciones (método privado)
  static Future<List<Map<String, dynamic>>> _obtenerViajesActivosUsuario() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/viajes/mis-viajes'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> viajes = data['data'];
          
          // Filtrar solo viajes activos
          return viajes
              .where((viaje) => viaje['estado'] == 'activo')
              .cast<Map<String, dynamic>>()
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('❌ Error obteniendo viajes activos: $e');
      return [];
    }
  }
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

  /// Obtener marcadores para el mapa (filtra automáticamente viajes pasados)
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
        
        // Filtrar marcadores que ya pasaron su hora de salida
        final marcadoresFiltrados = marcadoresData.where((marcadorJson) {
          try {
            final detallesViaje = marcadorJson['detalles_viaje'];
            if (detallesViaje != null && detallesViaje['fecha'] != null) {
              final fechaViaje = DateTime.parse(detallesViaje['fecha']);
              
              // Verificar si la fecha ya pasó (considerando zona horaria chilena)
              final fechaChile = fechaViaje.subtract(const Duration(hours: 4));
              final ahoraChile = DateTime.now();
              
              // Si ya pasó la hora de salida, cambiar estado automáticamente
              if (fechaChile.isBefore(ahoraChile)) {
                debugPrint('🕒 Viaje ${marcadorJson['id']} ya pasó su hora de salida, debe cambiar a en_curso');
                // Llamar al backend para cambiar estado (no esperar respuesta para no bloquear)
                cambiarEstadoViajeAsincrono(marcadorJson['id'], 'en_curso');
                return false; // No mostrar en el mapa
              }
            }
            return true;
          } catch (e) {
            debugPrint('❌ Error filtrando marcador: $e');
            return true; // En caso de error, mantener el marcador
          }
        }).toList();
        
        return marcadoresFiltrados
            .map((marcador) => MarcadorViaje.fromJson(marcador))
            .toList();
      } else {
        throw Exception('Error al obtener marcadores: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
  
  /// Cambiar estado de viaje de forma asíncrona (sin esperar respuesta)
  static void cambiarEstadoViajeAsincrono(String viajeId, String nuevoEstado) {
    _cambiarEstadoViajeAsync(viajeId, nuevoEstado).catchError((error) {
      debugPrint('❌ Error cambiando estado automático del viaje $viajeId: $error');
    });
  }
  
  /// Método auxiliar para cambio de estado asíncrono
  static Future<void> _cambiarEstadoViajeAsync(String viajeId, String nuevoEstado) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) return;

      await http.put(
        Uri.parse('$baseUrl/viajes/$viajeId/estado'),
        headers: headers,
        body: json.encode({'nuevoEstado': nuevoEstado}),
      );
      
      debugPrint('✅ Estado del viaje $viajeId cambiado automáticamente a $nuevoEstado');
    } catch (e) {
      debugPrint('❌ Error en cambio automático de estado: $e');
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

  /// Unirse a un viaje con información de pago
  static Future<Map<String, dynamic>> unirseAViajeConPago(
    String viajeId,
    String metodoPago,
    Map<String, dynamic>? datosAdicionales, {
    int pasajeros = 1,
    String? mensaje,
  }) async {
    try {
      print('🔍 Iniciando unirseAViajeConPago para viaje: $viajeId');
      
      // Verificar autenticación antes de hacer la petición
      final headers = await _getHeaders();
      if (headers == null) {
        print('❌ No hay headers de autenticación disponibles');
        return {
          'success': false,
          'message': 'Sesión expirada. Por favor, inicia sesión nuevamente.'
        };
      }
      
      print('✅ Headers de autenticación obtenidos');

      final body = {
        'pasajeros_solicitados': pasajeros,
        'metodo_pago': metodoPago,
        if (datosAdicionales != null) 'datos_pago': datosAdicionales,
        if (mensaje != null && mensaje.isNotEmpty) 'mensaje': mensaje,
      };

      final url = '$baseUrl/viajes/$viajeId/unirse-con-pago';
      print('🌐 Enviando petición a: $url');
      print('📦 Body: ${json.encode(body)}');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      print('📡 Respuesta recibida: ${response.statusCode}');
      print('📄 Contenido de respuesta: ${response.body}');

      // Verificar si la respuesta es JSON válido
      dynamic data;
      try {
        data = json.decode(response.body);
        print('✅ Respuesta JSON válida decodificada');
      } catch (e) {
        // Si no es JSON válido, probablemente es HTML (error del servidor)
        print('❌ Error decodificando JSON: $e');
        print('📄 Contenido raw: ${response.body.substring(0, 200)}...');
        return {
          'success': false,
          'message': 'Error del servidor: Respuesta no válida (Código: ${response.statusCode})'
        };
      }

      if (response.statusCode == 200) {
        print('✅ Petición exitosa');
        return {
          'success': true,
          'message': data['message'] ?? 'Solicitud con pago enviada exitosamente'
        };
      } else {
        print('❌ Error en la petición: ${response.statusCode}');
        return {
          'success': false,
          'message': data['message'] ?? 'Error al unirse al viaje con pago'
        };
      }
    } catch (e) {
      print('💥 Exception en unirseAViajeConPago: $e');
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
        Uri.parse('$baseUrl/notificaciones/viaje/$viajeId/abandonar'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Has abandonado el viaje exitosamente',
          'devolucion': data['data']?['devolucion'],
          'plazasLiberadas': data['data']?['plazasLiberadas'],
          'nuevasPlazasDisponibles': data['data']?['nuevasPlazasDisponibles']
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

  /// Eliminar un pasajero de un viaje (solo para conductores)
  /// Incluye lógica de reembolso automático
  static Future<Map<String, dynamic>> eliminarPasajero(String viajeId, String usuarioRut) async {
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

      // Llamada real al endpoint del backend
      final response = await http.delete(
        Uri.parse('$baseUrl/viajes/$viajeId/eliminar-pasajero/$usuarioRut'),
        headers: headers,
      );

      // Verificar si la respuesta es JSON válido
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        // Si no es JSON válido, probablemente es una página de error HTML
        return {
          'success': false,
          'message': 'Error del servidor (${response.statusCode}): La funcionalidad de eliminar pasajeros no está disponible en el backend.'
        };
      }

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Pasajero eliminado exitosamente',
          'data': data['data']
        };
      } else if (response.statusCode == 401) {
        // Token expirado o inválido
        await TokenManager.clearAuthData();
        return {
          'success': false,
          'message': 'Sesión expirada. Por favor, inicia sesión nuevamente.'
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message': 'No tienes permisos para eliminar pasajeros de este viaje.'
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'message': data['message'] ?? 'Viaje o pasajero no encontrado.'
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al eliminar el pasajero'
        };
      }
      
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// Obtener precio sugerido basado en coordenadas de ruta
  static Future<Map<String, dynamic>> obtenerPrecioSugerido({
    required double origenLat,
    required double origenLon,
    required double destinoLat,
    required double destinoLon,
    String? tipoVehiculo,
    Map<String, double>? factores,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No se pudo obtener el token de autenticación'
        };
      }

      final body = <String, dynamic>{
        'origenLat': origenLat,
        'origenLon': origenLon,
        'destinoLat': destinoLat,
        'destinoLon': destinoLon,
      };

      if (tipoVehiculo != null) {
        body['tipoVehiculo'] = tipoVehiculo;
      }

      if (factores != null) {
        body['factores'] = factores;
      }

      debugPrint("🔢 Solicitando precio sugerido para ruta:");
      debugPrint("   Origen: ($origenLat, $origenLon)");
      debugPrint("   Destino: ($destinoLat, $destinoLon)");
      debugPrint("   Tipo vehículo: $tipoVehiculo");

      final response = await http.post(
        Uri.parse('$baseUrl/viajes/precio-sugerido'),
        headers: headers,
        body: json.encode(body),
      );

      debugPrint("📨 Respuesta precio sugerido: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint("✅ Precio sugerido obtenido: ${data['data']}");
        
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? 'Precio calculado exitosamente'
        };
      } else {
        final data = json.decode(response.body);
        debugPrint("❌ Error en precio sugerido: ${data['message']}");
        
        return {
          'success': false,
          'message': data['message'] ?? 'Error al calcular precio sugerido'
        };
      }
    } catch (e) {
      debugPrint("💥 Error calculando precio sugerido: $e");
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

      // NUEVA LÓGICA: Mostrar SOS si:
      // 1. Es CONDUCTOR y el viaje está 'en_curso' (viaje iniciado)
      // 2. Es PASAJERO y el viaje está 'activo' o 'en_curso' (confirmado en viaje activo o en curso)
      final viajesConSOS = viajes.where((viaje) {
        try {          
          // El conductor es el usuario_rut principal del viaje
          final conductorRut = viaje['usuario_rut']?.toString();
          final estadoViaje = viaje['estado']?.toString().toLowerCase();
          
          debugPrint('🔍 Análisis viaje:');
          debugPrint('   - Conductor RUT: $conductorRut');
          debugPrint('   - Usuario actual RUT: $userRut');
          debugPrint('   - Estado del viaje: $estadoViaje');
          
          // Verificar si el viaje está en estado válido para SOS
          if (estadoViaje == 'completado' || estadoViaje == 'cancelado') {
            debugPrint('❌ Viaje completado o cancelado, no mostrar SOS');
            return false;
          }
          
          // CASO 1: Usuario es CONDUCTOR y viaje está EN_CURSO
          if (conductorRut == userRut) {
            if (estadoViaje == 'en_curso') {
              debugPrint('✅ Es conductor con viaje en curso, mostrar SOS');
              return true;
            } else {
              debugPrint('❌ Es conductor pero viaje no está en curso (estado: $estadoViaje)');
              return false;
            }
          }
          
          // CASO 2: Usuario es PASAJERO y viaje está ACTIVO o EN_CURSO
          if (estadoViaje == 'activo' || estadoViaje == 'en_curso') {
            // Verificar si hay pasajeros en el viaje
            final pasajeros = viaje['pasajeros'];
            if (pasajeros == null || pasajeros is! List) {
              debugPrint('❌ No hay lista de pasajeros');
              return false;
            }
            
            debugPrint('   - Total pasajeros: ${pasajeros.length}');
            
            // Verificar si el usuario actual está en la lista de pasajeros confirmados
            bool esUnPasajero = false;
            
            for (var pasajero in pasajeros) {
              if (pasajero is Map<String, dynamic>) {
                final pasajeroRut = pasajero['usuario_rut']?.toString();
                final estado = pasajero['estado']?.toString().toLowerCase();
                
                debugPrint('   - Pasajero RUT: $pasajeroRut, Estado: $estado');
                
                // Solo pasajeros confirmados pueden usar SOS
                if (pasajeroRut == userRut && estado == 'confirmado') {
                  esUnPasajero = true;
                  debugPrint('✅ Usuario encontrado como pasajero confirmado');
                  break;
                }
              }
            }
            
            if (!esUnPasajero) {
              debugPrint('❌ Usuario actual ($userRut) no es un pasajero confirmado en este viaje');
              return false;
            }
            
            debugPrint('✅ Es pasajero confirmado en viaje $estadoViaje, mostrar SOS');
            return true;
          } else {
            debugPrint('❌ Viaje no está activo ni en curso (estado: $estadoViaje)');
            return false;
          }
          
        } catch (e) {
          debugPrint('❌ Error procesando viaje: $e');
          return false;
        }
      }).toList();

      final resultado = viajesConSOS.isNotEmpty;
      debugPrint('🎯 RESULTADO FINAL: Mostrar SOS = $resultado (${viajesConSOS.length} viajes con SOS habilitado)');
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

      // Obtener fecha de hoy en hora chilena (UTC-4) para buscar viajes correctos
      final hoy = DateTime.now();
      // Ajustar a hora chilena para enviar la fecha correcta al backend
      final horaChilena = hoy.subtract(const Duration(hours: 4));
      final fechaHoy = "${horaChilena.year}-${horaChilena.month.toString().padLeft(2, '0')}-${horaChilena.day.toString().padLeft(2, '0')}";

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

  /// Obtener detalles del viaje activo para SOS
  static Future<Map<String, dynamic>?> obtenerDetallesViajeActivo() async {
    try {
      debugPrint('🔍 [VIAJE SERVICE] Iniciando obtenerDetallesViajeActivo');
      
      // Verificar autenticación primero
      if (await TokenManager.needsLogin()) {
        debugPrint('❌ Necesita login para obtener detalles del viaje');
        return null;
      }

      final headers = await _getHeaders();
      if (headers == null) {
        debugPrint('❌ No se pudo obtener headers para detalles del viaje');
        return null;
      }

      final rutUsuario = await _storage.read(key: 'user_rut');
      debugPrint('👤 RUT del usuario: $rutUsuario');
      if (rutUsuario == null) {
        debugPrint('❌ No se encontró RUT del usuario');
        return null;
      }

      // Usar el mismo endpoint que funciona para verificar viajes activos
      final url = Uri.parse('$baseUrl/viajes/mis-viajes');
      debugPrint('📡 Consultando URL: $url');
      final response = await http.get(url, headers: headers);

      debugPrint("📡 Obteniendo detalles viaje activo - Status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint("📊 Respuesta mis-viajes: $data");
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> viajes = data['data'];
          debugPrint("🚗 Total viajes: ${viajes.length}");
          
          // Buscar viajes donde el usuario pueda usar SOS (conductor en curso o pasajero en activo/curso)
          for (int i = 0; i < viajes.length; i++) {
            var viaje = viajes[i];
            debugPrint("🎯 Analizando viaje $i: ${viaje['_id']}");
            
            final String? estado = viaje['estado'];
            final String? conductorRut = viaje['usuario_rut'];
            
            debugPrint("   - Estado: $estado");
            debugPrint("   - Conductor: $conductorRut");
            
            // Verificar si el viaje está en un estado válido para SOS
            if (estado == 'completado' || estado == 'cancelado') {
              debugPrint("❌ Viaje completado o cancelado, saltando");
              continue;
            }
            
            bool puedeUsarSOS = false;
            String tipoUsuario = '';
            
            // CASO 1: Usuario es CONDUCTOR y viaje está EN_CURSO
            if (conductorRut == rutUsuario && estado == 'en_curso') {
              puedeUsarSOS = true;
              tipoUsuario = 'conductor';
              debugPrint("✅ Usuario es conductor con viaje en curso");
            }
            
            // CASO 2: Usuario es PASAJERO y viaje está ACTIVO o EN_CURSO
            if (!puedeUsarSOS && (estado == 'activo' || estado == 'en_curso')) {
              if (viaje['pasajeros'] != null) {
                final List<dynamic> pasajeros = viaje['pasajeros'];
                
                bool esPasajeroConfirmado = pasajeros.any((p) => 
                  p['usuario_rut'] == rutUsuario && 
                  p['estado'] == 'confirmado'
                );
                
                if (esPasajeroConfirmado) {
                  puedeUsarSOS = true;
                  tipoUsuario = 'pasajero';
                  debugPrint("✅ Usuario es pasajero confirmado en viaje $estado");
                }
              }
            }
            
            if (puedeUsarSOS) {
              debugPrint("🎯 ¡Usuario puede usar SOS como $tipoUsuario!");
              debugPrint("👨‍✈️ Conductor: ${viaje['conductor']}");
              debugPrint("🚗 Vehículo: ${viaje['vehiculo']}");
              debugPrint("📍 Origen: ${viaje['origen']?['nombre']}");
              debugPrint("📍 Destino: ${viaje['destino']?['nombre']}");
              
              // Obtener información del conductor y vehículo
              String nombreConductor = 'Conductor';
              String rutConductor = 'No disponible';
              String patente = 'No disponible';
              
              // Extraer datos del conductor
              if (viaje['conductor'] != null) {
                nombreConductor = viaje['conductor']['nombre'] ?? 'Conductor';
                rutConductor = viaje['conductor']['rut'] ?? viaje['usuario_rut'] ?? 'No disponible';
              } else {
                rutConductor = viaje['usuario_rut'] ?? 'No disponible';
              }
              
              // Extraer datos del vehículo
              if (viaje['vehiculo'] != null) {
                patente = viaje['vehiculo']['patente'] ?? viaje['vehiculo_patente'] ?? 'No disponible';
              } else {
                // Fallback a vehiculo_patente si no hay objeto vehiculo
                patente = viaje['vehiculo_patente'] ?? 'No disponible';
              }
              
              // Extraer información relevante para SOS (sin modelo y color)
              final infoExtraida = {
                'nombreConductor': nombreConductor,
                'rutConductor': rutConductor,
                'patente': patente,
                'origen': viaje['origen']?['nombre'] ?? 'No disponible',
                'destino': viaje['destino']?['nombre'] ?? 'No disponible',
                'tipoUsuario': tipoUsuario, // Añadido para identificar si es conductor o pasajero
              };
              debugPrint("📋 Información extraída para SOS: $infoExtraida");
              return infoExtraida;
            }
          }
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ Token expirado al obtener detalles del viaje');
        await TokenManager.clearAuthData();
        return null;
      }
      
      debugPrint('❌ No se encontró viaje activo donde el usuario pueda usar SOS');
      return null;
    } catch (e) {
      debugPrint('💥 Error obteniendo detalles del viaje activo: $e');
      return null;
    }
  }
}