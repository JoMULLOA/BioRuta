import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/confGlobal.dart';
import '../models/chat_grupal_models.dart';
import '../services/socket_service.dart';

class ChatGrupalService {
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static final SocketService _socketService = SocketService.instance;

  // Obtener información del viaje activo del usuario
  static Future<ChatGrupalInfo> obtenerViajeActivo() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        print('❌ No hay token disponible');
        return ChatGrupalInfo.empty();
      }

      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/viaje/activo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🚗 Respuesta viaje activo: ${response.statusCode}');
      print('🚗 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return ChatGrupalInfo.fromJson(data['data']);
        }
      }
      
      return ChatGrupalInfo.empty();
    } catch (e) {
      print('❌ Error obteniendo viaje activo: $e');
      return ChatGrupalInfo.empty();
    }
  }

  // Obtener mensajes del chat grupal
  static Future<List<MensajeGrupal>> obtenerMensajesGrupales(String idViaje) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        print('❌ No hay token disponible');
        return [];
      }

      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/chat/grupal/$idViaje/mensajes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🚗💬 Respuesta mensajes grupales: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> mensajesJson = data['data'];
          return mensajesJson.map((m) => MensajeGrupal.fromJson(m)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('❌ Error obteniendo mensajes grupales: $e');
      return [];
    }
  }

  // Obtener participantes del chat grupal
  static Future<List<ParticipanteChat>> obtenerParticipantes(String idViaje) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        print('❌ No hay token disponible');
        return [];
      }

      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/chat/grupal/$idViaje/participantes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🚗👥 Respuesta participantes: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> participantesJson = data['data'];
          return participantesJson.map((p) => ParticipanteChat.fromJson(p)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('❌ Error obteniendo participantes: $e');
      return [];
    }
  }

  // Verificar si el usuario está en un chat grupal
  static Future<bool> verificarEstaEnChatGrupal(String idViaje) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        print('❌ No hay token disponible');
        return false;
      }

      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/chat/grupal/$idViaje/estado'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🚗📊 Respuesta estado chat: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data']['estaEnChat'] ?? false;
        }
      }
      
      return false;
    } catch (e) {
      print('❌ Error verificando estado chat grupal: $e');
      return false;
    }
  }

  // Unirse al chat grupal (a través del socket)
  static void unirseAlChatGrupal(String idViaje) {
    print('🚗✅ Uniéndose al chat grupal: $idViaje');
    _socketService.joinGroupChat(idViaje);
  }

  // Salir del chat grupal (a través del socket)
  static void salirDelChatGrupal(String idViaje) {
    print('🚗❌ Saliendo del chat grupal: $idViaje');
    _socketService.leaveGroupChat(idViaje);
  }

  // Enviar mensaje al chat grupal (a través del socket)
  static void enviarMensajeGrupal(String idViaje, String contenido) {
    print('🚗📤 Enviando mensaje grupal: $contenido');
    _socketService.sendGroupMessage(idViaje, contenido);
  }

  // Editar mensaje grupal (a través del socket)
  static void editarMensajeGrupal(String idViaje, int idMensaje, String nuevoContenido) {
    print('🚗✏️ Editando mensaje grupal: $idMensaje');
    _socketService.editGroupMessage(
      idMensaje: idMensaje,
      nuevoContenido: nuevoContenido,
      idViaje: idViaje,
    );
  }

  // Eliminar mensaje grupal (a través del socket)
  static void eliminarMensajeGrupal(String idViaje, int idMensaje) {
    print('🚗🗑️ Eliminando mensaje grupal: $idMensaje');
    _socketService.deleteGroupMessage(
      idMensaje: idMensaje,
      idViaje: idViaje,
    );
  }

  // Obtener estado del chat grupal (a través del socket)
  static void obtenerEstadoChatGrupal(String idViaje) {
    print('🚗📊 Obteniendo estado chat grupal: $idViaje');
    _socketService.getGroupChatState(idViaje);
  }

  // Colores para los participantes del chat grupal
  static List<int> get coloresParticipantes => [
    0xFF6B3B2D, // Marrón principal
    0xFF8D4F3A, // Marrón secundario
    0xFFB8860B, // Dorado oscuro
    0xFFCD853F, // Dorado claro
    0xFFD2691E, // Naranja chocolate
    0xFFA0522D, // Sienna
  ];

  // Obtener color para un participante específico
  static int obtenerColorParticipante(String rutParticipante) {
    final index = rutParticipante.hashCode % coloresParticipantes.length;
    return coloresParticipantes[index];
  }

  // Obtener color más claro para fondos
  static int obtenerColorFondoParticipante(String rutParticipante) {
    final colorBase = obtenerColorParticipante(rutParticipante);
    // Hacer el color más claro añadiendo opacidad
    return colorBase | 0x20000000; // Agregar 20% de opacidad
  }

  // Verificar si un mensaje es del usuario actual
  static Future<bool> esMensajePropio(String emisorRut) async {
    final userRut = await _storage.read(key: 'user_rut');
    return userRut == emisorRut;
  }

  // Obtener el RUT del usuario actual
  static Future<String?> obtenerRutUsuarioActual() async {
    return await _storage.read(key: 'user_rut');
  }

  // Formatear fecha para mostrar en el chat
  static String formatearFecha(DateTime fecha) {
    final now = DateTime.now();
    final difference = now.difference(fecha);

    if (difference.inDays == 0) {
      // Hoy - mostrar solo la hora
      return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Ayer
      return 'Ayer ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      // Esta semana
      const diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return '${diasSemana[fecha.weekday - 1]} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else {
      // Más de una semana
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }
}
