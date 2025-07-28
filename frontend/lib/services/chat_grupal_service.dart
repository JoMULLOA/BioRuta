import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/confGlobal.dart';
import '../models/chat_grupal_models.dart';
import '../models/viaje_chat_model.dart';
import '../services/socket_service.dart';
import '../utils/date_utils.dart' as date_utils;

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
        Uri.parse('${confGlobal.baseUrl}/viajes/mis-viajes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🚗 Respuesta mis-viajes: ${response.statusCode}');
      print('🚗 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> viajes = data['data'];
          
          // Buscar el primer viaje que esté activo/en progreso con pasajeros confirmados
          for (var viajeData in viajes) {
            final estado = viajeData['estado']?.toString().toLowerCase();
            final List<dynamic> pasajeros = viajeData['pasajeros'] ?? [];
            
            // Verificar si hay pasajeros confirmados
            bool hayPasajerosConfirmados = pasajeros.any((p) => p['estado'] == 'confirmado');
            
            if ((estado == 'activo' || estado == 'en_progreso' || estado == 'confirmado') && hayPasajerosConfirmados) {
              print('🚗✅ Viaje activo con pasajeros encontrado: ${viajeData['_id']}');
              print('🚗👥 Pasajeros confirmados: ${pasajeros.where((p) => p['estado'] == 'confirmado').length}');
              return ChatGrupalInfo.fromJson(viajeData);
            }
          }
          
          print('🚗📴 No se encontraron viajes activos con pasajeros confirmados');
        }
      }
      
      return ChatGrupalInfo.empty();
    } catch (e) {
      print('❌ Error obteniendo viaje activo: $e');
      return ChatGrupalInfo.empty();
    }
  }

  // Obtener todos los viajes donde el usuario está confirmado (para lista de chats)
  static Future<List<ViajeChat>> obtenerMisViajesParaChat() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final userRut = await _storage.read(key: 'user_rut');
      
      if (token == null || userRut == null) {
        print('❌ No hay token o RUT disponible');
        return [];
      }

      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/viajes/mis-viajes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🚗 Respuesta mis-viajes-chat: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> viajes = data['data'];
          List<ViajeChat> viajesParaChat = [];
          
          for (var viajeData in viajes) {
            final estado = viajeData['estado']?.toString().toLowerCase();
            final List<dynamic> pasajeros = viajeData['pasajeros'] ?? [];
            final conductorRut = viajeData['usuario_rut'];
            
            // Verificar si hay pasajeros confirmados O si soy el conductor
            bool hayPasajerosConfirmados = pasajeros.any((p) => p['estado'] == 'confirmado');
            bool soyElConductor = conductorRut == userRut;
            
            // Solo incluir viajes activos con pasajeros confirmados O donde soy conductor
            if ((estado == 'activo' || estado == 'en_progreso' || estado == 'confirmado') && 
                (hayPasajerosConfirmados || soyElConductor)) {
              
              var viajeChat = ViajeChat.fromJson(viajeData);
              // Establecer si soy el conductor
              viajeChat = ViajeChat(
                idViaje: viajeChat.idViaje,
                origen: viajeChat.origen,
                destino: viajeChat.destino,
                fechaViaje: viajeChat.fechaViaje,
                horaViaje: viajeChat.horaViaje,
                conductorNombre: viajeChat.conductorNombre,
                conductorRut: viajeChat.conductorRut,
                cantidadPasajeros: viajeChat.cantidadPasajeros,
                soyElConductor: soyElConductor,
                estado: viajeChat.estado,
              );
              
              viajesParaChat.add(viajeChat);
              print('🚗✅ Viaje agregado para chat: ${viajeChat.idViaje} - ${viajeChat.rutaCompleta}');
            }
          }
          
          print('🚗📋 Total viajes para chat: ${viajesParaChat.length}');
          return viajesParaChat;
        }
      }
      
      return [];
    } catch (e) {
      print('❌ Error obteniendo viajes para chat: $e');
      return [];
    }
  }

  // Obtener mensajes del chat grupal (usando endpoint de viaje)
  static Future<List<MensajeGrupal>> obtenerMensajesGrupales(String idViaje) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        print('❌ No hay token disponible');
        return [];
      }

      // Primero obtenemos los participantes para mapear RUT -> Nombre
      final participantes = await obtenerParticipantes(idViaje);
      final Map<String, String> rutANombre = {};
      for (var participante in participantes) {
        rutANombre[participante.rut] = participante.nombre;
      }
      
      print('🚗💬 Mapeando participantes: $rutANombre');

      // CORRECCIÓN: Usar endpoint de viaje, no de chat grupal específico
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/chat/viaje/$idViaje/mensajes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🚗💬 Respuesta mensajes viaje: ${response.statusCode}');
      print('🚗💬 Body respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // CORRECCIÓN: El backend puede devolver directamente el array o wrapped en un objeto
        List<dynamic> mensajesJson;
        
        if (responseData is List) {
          // Respuesta directa como array
          print('🚗💬 Respuesta directa como array');
          mensajesJson = responseData;
        } else if (responseData is Map && responseData['success'] == true && responseData['data'] != null) {
          // Respuesta envuelta en objeto con success/data
          print('🚗💬 Respuesta envuelta en objeto success/data');
          mensajesJson = responseData['data'];
        } else {
          print('🚗💬 Formato de respuesta no reconocido');
          return [];
        }
        
        // Filtrar solo mensajes grupales y convertirlos
        final mensajesGrupales = <MensajeGrupal>[];
        for (var mensajeData in mensajesJson) {
          // Verificar si es mensaje grupal (no tiene receptor específico)
          if (mensajeData['tipo'] == 'grupal' || mensajeData['receptor'] == null) {
            try {
              // ENRIQUECER: Agregar el nombre del emisor basado en el RUT
              final emisorRut = mensajeData['emisor'] ?? mensajeData['emisorRut'] ?? '';
              final emisorNombre = rutANombre[emisorRut] ?? 'Usuario';
              
              // Asegurar que el JSON tenga el emisorNombre
              mensajeData['emisorNombre'] = emisorNombre;
              
              final mensaje = MensajeGrupal.fromJson(mensajeData);
              mensajesGrupales.add(mensaje);
              
              print('🚗💬 Mensaje enriquecido: ${mensaje.emisorNombre} (${mensaje.emisorRut}): ${mensaje.contenido}');
            } catch (e) {
              print('⚠️ Error parseando mensaje grupal: $e');
              print('⚠️ Datos del mensaje: $mensajeData');
            }
          }
        }
        
        print('🚗💬 Mensajes grupales cargados: ${mensajesGrupales.length}');
        return mensajesGrupales;
      }
      
      return [];
    } catch (e) {
      print('❌ Error obteniendo mensajes grupales: $e');
      return [];
    }
  }

  // Obtener participantes del chat grupal (basado en pasajeros confirmados del viaje)
  static Future<List<ParticipanteChat>> obtenerParticipantes(String idViaje) async {
    try {
      // Los participantes del chat grupal son los pasajeros confirmados del viaje
      // más el conductor. Vamos a obtenerlos directamente del viaje.
      final viajeInfo = await obtenerViajeActivo();
      if (viajeInfo.idViaje.isEmpty || viajeInfo.idViaje != idViaje) {
        print('❌ No se pudo obtener información del viaje para participantes');
        return [];
      }

      final participantes = <ParticipanteChat>[];
      
      // Obtener los datos raw del viaje para acceder a los pasajeros
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        print('❌ No hay token disponible para obtener participantes');
        return [];
      }

      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/viajes/mis-viajes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> viajes = data['data'];
          
          // Buscar el viaje específico
          Map<String, dynamic>? viajeData;
          for (var viaje in viajes) {
            if (viaje['_id'] == idViaje) {
              viajeData = viaje;
              break;
            }
          }
          
          if (viajeData == null) {
            print('❌ No se encontró el viaje específico para participantes');
            return [];
          }
          
          // Agregar el conductor
          final conductorRut = viajeData['usuario_rut'];
          if (conductorRut != null) {
            participantes.add(ParticipanteChat(
              rut: conductorRut,
              nombre: 'Conductor', // Nombre por defecto, se puede mejorar después
              esConductor: true,
              estaConectado: true,
            ));
          }
          
          // Agregar pasajeros confirmados
          final List<dynamic> pasajeros = viajeData['pasajeros'] ?? [];
          for (var pasajero in pasajeros) {
            if (pasajero['estado'] == 'confirmado') {
              final rutPasajero = pasajero['usuario_rut'];
              final nombrePasajero = pasajero['usuario']?['nombre'] ?? 'Pasajero';
              
              if (rutPasajero != null) {
                participantes.add(ParticipanteChat(
                  rut: rutPasajero,
                  nombre: nombrePasajero,
                  esConductor: false,
                  estaConectado: true,
                ));
              }
            }
          }
        }
      }

      print('🚗👥 Participantes obtenidos del viaje: ${participantes.length}');
      print('🚗👥 Conductor: ${participantes.where((p) => p.esConductor).length}');
      print('🚗👥 Pasajeros: ${participantes.where((p) => !p.esConductor).length}');
      
      return participantes;
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

  // Crear/inicializar chat grupal manualmente (para casos donde no se creó automáticamente)
  static Future<bool> inicializarChatGrupal(String idViaje) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        print('❌ No hay token disponible');
        return false;
      }

      print('🚗🔧 Intentando forzar la creación del chat grupal...');
      
      // Obtener información del viaje para identificar si somos conductor o pasajero
      final viajeInfo = await obtenerViajeActivo();
      if (viajeInfo.idViaje.isEmpty) {
        print('❌ No se pudo obtener información del viaje activo');
        return false;
      }
      
      final userRut = await _storage.read(key: 'user_rut');
      if (userRut == null) {
        print('❌ No hay RUT de usuario disponible');
        return false;
      }
      
      print('🚗✅ Viaje encontrado: ${viajeInfo.idViaje}');
      print('🚗� Usuario actual: $userRut');
      print('🚗👤 Conductor del viaje: ${viajeInfo.conductorRut}');
      
      // Estrategia: Forzar la creación del chat grupal usando la API de confirmación
      // Si somos el conductor, nos "auto-confirmamos" en nuestro propio viaje
      // Si somos pasajero, nos re-confirmamos
      
      print('🚗🔧 Intentando forzar creación vía auto-confirmación...');
      final confirmResponse = await http.put(
        Uri.parse('${confGlobal.baseUrl}/viajes/$idViaje/confirmar/$userRut'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🚗🆕 Respuesta auto-confirmación: ${confirmResponse.statusCode}');
      print('🚗🆕 Body respuesta: ${confirmResponse.body}');

      // Independientemente del resultado de la confirmación, intentar unirse por socket
      print('🚗🔧 Intentando unirse al chat grupal por socket...');
      _socketService.joinGroupChat(idViaje);
      
      // Esperar un poco para que el socket procese
      await Future.delayed(const Duration(seconds: 3));
      
      // Verificar si ahora podemos obtener participantes (indica que el chat existe)
      final participantesResponse = await http.get(
        Uri.parse('${confGlobal.baseUrl}/chat/grupal/$idViaje/participantes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🚗📊 Respuesta post-socket participantes: ${participantesResponse.statusCode}');
      
      if (participantesResponse.statusCode == 200) {
        final participantesData = json.decode(participantesResponse.body);
        if (participantesData['success'] == true) {
          print('🚗✅ Chat grupal ahora existe después de la unión por socket');
          print('🚗👥 Participantes actuales: ${participantesData['data']}');
          return true;
        }
      } else if (participantesResponse.statusCode == 404) {
        print('🚗❌ Chat grupal AÚN NO EXISTE después del intento');
        print('🚗🔧 PROBLEMA: El backend no está creando automáticamente el chat grupal');
        print('🚗🔧 Es necesario revisar la función crearChatGrupal en el backend');
      }

      print('❌ Chat grupal no pudo ser inicializado via socket');
      return false;
    } catch (e) {
      print('❌ Error inicializando chat grupal: $e');
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
    // Convertir la fecha UTC a hora local de Chile
    final fechaChile = date_utils.DateUtils.utcAHoraChile(fecha);
    final now = DateTime.now();
    final nowChile = date_utils.DateUtils.utcAHoraChile(now.toUtc());
    final difference = nowChile.difference(fechaChile);

    if (difference.inDays == 0) {
      // Hoy - mostrar solo la hora
      return date_utils.DateUtils.obtenerHoraChile(fecha);
    } else if (difference.inDays == 1) {
      // Ayer
      return 'Ayer ${date_utils.DateUtils.obtenerHoraChile(fecha)}';
    } else if (difference.inDays < 7) {
      // Esta semana
      const diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return '${diasSemana[fechaChile.weekday - 1]} ${date_utils.DateUtils.obtenerHoraChile(fecha)}';
    } else {
      // Más de una semana
      return date_utils.DateUtils.obtenerFechaChile(fecha);
    }
  }
}
