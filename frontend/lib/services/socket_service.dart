import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/confGlobal.dart';
import 'dart:async';

class SocketService {
  static SocketService? _instance;
  IO.Socket? socket;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // StreamControllers para manejar eventos
  final StreamController<Map<String, dynamic>> _messageStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionStreamController = 
      StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _editedMessageStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _deletedMessageStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // StreamControllers específicos para chat grupal
  final StreamController<Map<String, dynamic>> _groupMessageStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _groupParticipantsStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _groupChatEventsStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Getters para los streams
  Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;
  Stream<bool> get connectionStream => _connectionStreamController.stream;
  Stream<Map<String, dynamic>> get editedMessageStream => _editedMessageStreamController.stream;
  Stream<Map<String, dynamic>> get deletedMessageStream => _deletedMessageStreamController.stream;
  
  // Getters para streams de chat grupal
  Stream<Map<String, dynamic>> get groupMessageStream => _groupMessageStreamController.stream;
  Stream<Map<String, dynamic>> get groupParticipantsStream => _groupParticipantsStreamController.stream;
  Stream<Map<String, dynamic>> get groupChatEventsStream => _groupChatEventsStreamController.stream;
  
  // Callback para nuevos mensajes (mantiene compatibilidad)
  Function(dynamic)? _onNewMessageCallback;
  
  // Singleton pattern para una sola instancia
  static SocketService get instance {
    _instance ??= SocketService._internal();
    return _instance!;
  }
  
  SocketService._internal();

  // Conectar al servidor WebSocket
  Future<void> connect() async {
    if (socket?.connected == true) {
      print('🔌 Socket ya está conectado');
      _connectionStreamController.add(true);
      return;
    }

    try {
      final token = await _storage.read(key: 'jwt_token');
      final userRut = await _storage.read(key: 'user_rut');
      
      if (token == null || userRut == null) {
        print('❌ No hay token o RUT para conectar socket');
        print('❌ Token: ${token != null ? "Disponible" : "NULL"}');
        print('❌ RUT: ${userRut != null ? "Disponible" : "NULL"}');
        _connectionStreamController.add(false);
        return;
      }

      // Socket.IO necesita conectarse sin el /api path
      final socketUrl = confGlobal.baseUrl.replaceAll('/api', '');
      print('🔌 Conectando socket a: $socketUrl');
      print('🔌 Con token: ${token.substring(0, 20)}...');
      print('🔌 Con RUT: $userRut');
      
      socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'], // Agregamos polling como fallback
        'autoConnect': false,
        'timeout': 20000,
        'forceNew': true, // Fuerza una nueva conexión
        'auth': {
          'token': token,
          'rut': userRut,
        }
      });

      socket!.connect();

      socket!.onConnect((_) {
        print('🔌 Conectado al servidor WebSocket');
        _connectionStreamController.add(true);
        // No necesitamos registrar manualmente, se hace automáticamente con auth
      });

      socket!.onDisconnect((_) {
        print('🔌 Desconectado del servidor WebSocket');
        _connectionStreamController.add(false);
      });

      socket!.onConnectError((error) {
        print('❌ Error de conexión WebSocket: $error');
        _connectionStreamController.add(false);
      });

      // Escuchar nuevos mensajes
      socket!.on('nuevo_mensaje', (data) {
        print('💬 Nuevo mensaje recibido: $data');
        _handleNewMessage(data);
      });

      // Escuchar mensaje editado
      socket!.on('mensaje_editado', (data) {
        print('✏️ Mensaje editado recibido: $data');
        print('✏️ Tipo de data: ${data.runtimeType}');
        _handleEditedMessage(data);
      });

      // Escuchar mensaje eliminado
      socket!.on('mensaje_eliminado', (data) {
        print('🗑️ Mensaje eliminado recibido: $data');
        print('🗑️ Tipo de data: ${data.runtimeType}');
        _handleDeletedMessage(data);
      });

      // Escuchar confirmación de edición exitosa
      socket!.on('edicion_exitosa', (data) {
        print('✅ Edición exitosa confirmada: $data');
      });

      // Escuchar confirmación de eliminación exitosa
      socket!.on('eliminacion_exitosa', (data) {
        print('✅ Eliminación exitosa confirmada: $data');
      });

      // Escuchar errores de edición
      socket!.on('error_edicion', (data) {
        print('❌ Error de edición: $data');
      });

      // Escuchar errores de eliminación
      socket!.on('error_eliminacion', (data) {
        print('❌ Error de eliminación: $data');
      });

      // === EVENTOS ESPECÍFICOS PARA CHAT GRUPAL ===

      // Mensaje grupal recibido
      socket!.on('nuevo_mensaje_grupal', (data) {
        print('🚗💬 Nuevo mensaje grupal recibido: $data');
        _handleGroupMessage(data);
      });

      // Participante se unió al chat grupal
      socket!.on('participante_unido', (data) {
        print('🚗➕ Participante unido al chat grupal: $data');
        _handleParticipantJoined(data);
      });

      // Participante salió del chat grupal
      socket!.on('participante_salio', (data) {
        print('🚗➖ Participante salió del chat grupal: $data');
        _handleParticipantLeft(data);
      });

      // Confirmación de unión al chat grupal
      socket!.on('unido_chat_grupal', (data) {
        print('🚗✅ Confirmación unión chat grupal: $data');
        _handleGroupChatJoined(data);
      });

      // Confirmación de salida del chat grupal
      socket!.on('salio_chat_grupal', (data) {
        print('🚗❌ Confirmación salida chat grupal: $data');
        _handleGroupChatLeft(data);
      });

      // Estado del chat grupal
      socket!.on('estado_chat_grupal', (data) {
        print('🚗📊 Estado chat grupal: $data');
        _handleGroupChatState(data);
      });

      // Notificación de chat grupal creado
      socket!.on('chat_grupal_creado', (data) {
        print('🚗🆕 Chat grupal creado: $data');
        _handleGroupChatCreated(data);
      });

      // Notificación de chat grupal finalizado
      socket!.on('chat_grupal_finalizado', (data) {
        print('🚗🏁 Chat grupal finalizado: $data');
        _handleGroupChatFinished(data);
      });

      // Notificación de agregado al chat grupal
      socket!.on('agregado_chat_grupal', (data) {
        print('🚗➕ Agregado al chat grupal: $data');
        _handleAddedToGroupChat(data);
      });

      // Notificación de eliminado del chat grupal
      socket!.on('eliminado_chat_grupal', (data) {
        print('🚗➖ Eliminado del chat grupal: $data');
        _handleRemovedFromGroupChat(data);
      });

      // Participante agregado al chat grupal
      socket!.on('participante_agregado', (data) {
        print('🚗👥 Participante agregado: $data');
        _handleParticipantAdded(data);
      });

      // Participante eliminado del chat grupal
      socket!.on('participante_eliminado', (data) {
        print('🚗👥 Participante eliminado: $data');
        _handleParticipantRemoved(data);
      });

      // Confirmación de mensaje grupal enviado
      socket!.on('mensaje_grupal_enviado', (data) {
        print('🚗✅ Mensaje grupal enviado confirmado: $data');
      });

      // Errores específicos del chat grupal
      socket!.on('error_chat_grupal', (data) {
        print('🚗❌ Error chat grupal: $data');
      });

      socket!.on('error_mensaje_grupal', (data) {
        print('🚗❌ Error mensaje grupal: $data');
        _handleGroupMessageError(data);
      });

      // Edición grupal
      socket!.on('edicion_grupal_exitosa', (data) {
        print('🚗✅ Edición grupal exitosa: $data');
      });

      socket!.on('error_edicion_grupal', (data) {
        print('🚗❌ Error edición grupal: $data');
      });

      // Eliminación grupal
      socket!.on('eliminacion_grupal_exitosa', (data) {
        print('🚗✅ Eliminación grupal exitosa: $data');
      });

      socket!.on('error_eliminacion_grupal', (data) {
        print('🚗❌ Error eliminación grupal: $data');
      });

      // Escuchar confirmación de mensaje enviado
      socket!.on('mensaje_enviado', (data) {
        print('✅ Mensaje enviado confirmado: $data');
      });

      // Escuchar errores de mensaje
      socket!.on('error_mensaje', (data) {
        print('❌ Error de mensaje: $data');
      });

      // === EVENTOS DE PETICIONES DE SUPERVISIÓN ===
      
      // Escuchar respuestas a peticiones de supervisión
      socket!.on('respuesta_peticion_supervision', (data) {
        print('📋 Respuesta de petición de supervisión recibida: $data');
        _handlePeticionSupervisionResponse(data);
      });

      // Escuchar nuevas peticiones de supervisión (para administradores)
      socket!.on('nueva_peticion_supervision', (data) {
        print('📋 Nueva petición de supervisión recibida: $data');
        _handleNuevaPeticionSupervision(data);
      });

      // Escuchar cuando una petición es marcada como solucionada
      socket!.on('peticion_solucionada', (data) {
        print('📋 Petición marcada como solucionada: $data');
        _handlePeticionSolucionada(data);
      });

      // Esperar un poco para que la conexión se establezca
      await Future.delayed(Duration(milliseconds: 500));
      
      // Emitir estado inicial después de intentar conectar
      _connectionStreamController.add(socket?.connected == true);

    } catch (e) {
      print('❌ Error conectando socket: $e');
      _connectionStreamController.add(false);
    }
  }

  // Enviar mensaje via WebSocket
  void sendMessage({
    required String contenido,
    required String receptorRut,
    String? idViajeMongo,
  }) {
    if (socket?.connected != true) {
      print('❌ Socket no conectado, no se puede enviar mensaje');
      return;
    }

    final messageData = {
      'contenido': contenido,
      'receptorRut': receptorRut,
      if (idViajeMongo != null) 'idViajeMongo': idViajeMongo,
    };

    print('📤 Enviando mensaje via socket: $messageData');
    socket!.emit('enviar_mensaje', messageData);
  }

  // Editar mensaje via WebSocket
  void editMessage({
    required int idMensaje,
    required String nuevoContenido,
  }) {
    print('🔍 DEBUG: editMessage llamado con idMensaje=$idMensaje, nuevoContenido=$nuevoContenido');
    
    if (socket?.connected != true) {
      print('❌ Socket no conectado, no se puede editar mensaje');
      return;
    }

    final messageData = {
      'idMensaje': idMensaje,
      'nuevoContenido': nuevoContenido,
    };

    print('✏️ Editando mensaje via socket: $messageData');
    socket!.emit('editar_mensaje', messageData);
  }

  // Editar mensaje grupal via WebSocket
  void editGroupMessage({
    required int idMensaje,
    required String nuevoContenido,
    required String idViaje,
  }) {
    print('🔍 DEBUG: editGroupMessage llamado con idMensaje=$idMensaje, nuevoContenido=$nuevoContenido, idViaje=$idViaje');
    
    if (socket?.connected != true) {
      print('❌ Socket no conectado, no se puede editar mensaje grupal');
      return;
    }

    final messageData = {
      'idMensaje': idMensaje,
      'nuevoContenido': nuevoContenido,
      'idViaje': idViaje,
    };

    print('✏️ Editando mensaje grupal via socket: $messageData');
    socket!.emit('editar_mensaje_grupal', messageData);
  }

  // Eliminar mensaje via WebSocket
  void deleteMessage({
    required int idMensaje,
  }) {
    print('🔍 DEBUG: deleteMessage llamado con idMensaje=$idMensaje');
    
    if (socket?.connected != true) {
      print('❌ Socket no conectado, no se puede eliminar mensaje');
      return;
    }

    final messageData = {
      'idMensaje': idMensaje,
    };

    print('🗑️ Eliminando mensaje via socket: $messageData');
    socket!.emit('eliminar_mensaje', messageData);
  }

  // Eliminar mensaje grupal via WebSocket
  void deleteGroupMessage({
    required int idMensaje,
    required String idViaje,
  }) {
    print('🔍 DEBUG: deleteGroupMessage llamado con idMensaje=$idMensaje, idViaje=$idViaje');
    
    if (socket?.connected != true) {
      print('❌ Socket no conectado, no se puede eliminar mensaje grupal');
      return;
    }

    final messageData = {
      'idMensaje': idMensaje,
      'idViaje': idViaje,
    };

    print('🗑️ Eliminando mensaje grupal via socket: $messageData');
    socket!.emit('eliminar_mensaje_grupal', messageData);
  }

  // === MÉTODOS PARA CHAT GRUPAL ===

  // Unirse al chat grupal
  void joinGroupChat(String idViaje) {
    if (socket?.connected != true) {
      print('❌ Socket no conectado, no se puede unir al chat grupal');
      return;
    }

    print('🚗📝 Uniéndose al chat grupal del viaje: $idViaje');
    socket!.emit('unirse_chat_grupal', {'idViaje': idViaje});
  }

  // Salir del chat grupal
  void leaveGroupChat(String idViaje) {
    if (socket?.connected != true) {
      print('❌ Socket no conectado, no se puede salir del chat grupal');
      return;
    }

    print('🚗📝 Saliendo del chat grupal del viaje: $idViaje');
    socket!.emit('salir_chat_grupal', {'idViaje': idViaje});
  }

  // Enviar mensaje al chat grupal
  void sendGroupMessage(String idViaje, String contenido) {
    if (socket?.connected != true) {
      print('❌ Socket no conectado, no se puede enviar mensaje grupal');
      return;
    }

    final messageData = {
      'idViaje': idViaje,
      'contenido': contenido,
    };

    print('🚗📤 Enviando mensaje grupal: $messageData');
    socket!.emit('enviar_mensaje_grupal', messageData);
  }

  // Obtener estado del chat grupal
  void getGroupChatState(String idViaje) {
    if (socket?.connected != true) {
      print('❌ Socket no conectado, no se puede obtener estado del chat grupal');
      return;
    }

    print('🚗📊 Obteniendo estado del chat grupal: $idViaje');
    socket!.emit('obtener_estado_chat_grupal', {'idViaje': idViaje});
  }

  // Unirse a chat de viaje
  void joinViajeChat(String idViaje) {
    if (socket?.connected == true) {
      socket!.emit('unirse_viaje', idViaje);
      print('🚗 Uniéndose a chat de viaje: $idViaje');
    }
  }

  // Salir de chat de viaje
  void leaveViajeChat(String idViaje) {
    if (socket?.connected == true) {
      socket!.emit('salir_viaje', idViaje);
      print('🚗 Saliendo de chat de viaje: $idViaje');
    }
  }

  // Reconectar usuario
  void reconnectUser() {
    if (socket?.connected == true) {
      socket!.emit('reconectar_usuario');
      print('🔄 Reconectando usuario');
    }
  }

  // Manejar nuevos mensajes recibidos
  void _handleNewMessage(dynamic data) {
    try {
      final messageData = Map<String, dynamic>.from(data);
      
      // Emitir a través del stream
      _messageStreamController.add(messageData);
      
      // Mantener compatibilidad con callback
      if (_onNewMessageCallback != null) {
        _onNewMessageCallback!(data);
      }
    } catch (e) {
      print('❌ Error procesando mensaje: $e');
    }
  }

  // Manejar mensajes editados
  void _handleEditedMessage(dynamic data) {
    try {
      print('📝 Procesando mensaje editado en service: $data');
      final messageData = Map<String, dynamic>.from(data);
      
      // Emitir a través del stream específico para mensajes editados
      print('📝 Emitiendo mensaje editado a stream específico');
      _editedMessageStreamController.add(messageData);
      
      // También emitir en el stream general con marca para compatibilidad
      messageData['_isEdited'] = true;
      _messageStreamController.add(messageData);
      
      // Mantener compatibilidad con callback
      if (_onNewMessageCallback != null) {
        _onNewMessageCallback!(data);
      }
      
      print('📝 Mensaje editado procesado exitosamente');
    } catch (e) {
      print('❌ Error procesando mensaje editado: $e');
    }
  }

  // Manejar mensajes eliminados
  void _handleDeletedMessage(dynamic data) {
    try {
      print('🗑️ Procesando mensaje eliminado en service: $data');
      final messageData = Map<String, dynamic>.from(data);
      
      // Convertir formato del backend al formato del frontend
      if (messageData.containsKey('idMensaje')) {
        messageData['id'] = messageData['idMensaje']; // Backend envía 'idMensaje', frontend espera 'id'
      }
      
      // Emitir a través del stream específico para mensajes eliminados
      print('🗑️ Emitiendo mensaje eliminado a stream específico');
      _deletedMessageStreamController.add(messageData);
      
      // También emitir en el stream general con marca para compatibilidad
      messageData['_isDeleted'] = true;
      _messageStreamController.add(messageData);
      
      // Mantener compatibilidad con callback
      if (_onNewMessageCallback != null) {
        _onNewMessageCallback!(data);
      }
      
      print('🗑️ Mensaje eliminado procesado exitosamente');
    } catch (e) {
      print('❌ Error procesando mensaje eliminado: $e');
    }
  }

  // === HANDLERS PARA EVENTOS DE CHAT GRUPAL ===

  // Manejar mensaje grupal recibido
  void _handleGroupMessage(dynamic data) {
    try {
      print('🚗💬 Procesando mensaje grupal en service: $data');
      final messageData = Map<String, dynamic>.from(data);
      
      // Marcar como mensaje grupal
      messageData['_isGroupMessage'] = true;
      
      // Emitir a streams específicos
      _groupMessageStreamController.add(messageData);
      _messageStreamController.add(messageData); // También al stream general
      
      print('🚗💬 Mensaje grupal procesado exitosamente');
    } catch (e) {
      print('❌ Error procesando mensaje grupal: $e');
    }
  }

  // Manejar participante que se unió
  void _handleParticipantJoined(dynamic data) {
    try {
      print('🚗➕ Procesando participante unido: $data');
      final eventData = Map<String, dynamic>.from(data);
      eventData['_eventType'] = 'participant_joined';
      
      _groupParticipantsStreamController.add(eventData);
      _groupChatEventsStreamController.add(eventData);
      
      print('🚗➕ Participante unido procesado exitosamente');
    } catch (e) {
      print('❌ Error procesando participante unido: $e');
    }
  }

  // Manejar participante que salió
  void _handleParticipantLeft(dynamic data) {
    try {
      print('🚗➖ Procesando participante salió: $data');
      final eventData = Map<String, dynamic>.from(data);
      eventData['_eventType'] = 'participant_left';
      
      _groupParticipantsStreamController.add(eventData);
      _groupChatEventsStreamController.add(eventData);
      
      print('🚗➖ Participante salió procesado exitosamente');
    } catch (e) {
      print('❌ Error procesando participante salió: $e');
    }
  }

  // Manejar confirmación de unión al chat grupal
  void _handleGroupChatJoined(dynamic data) {
    try {
      print('🚗✅ Procesando confirmación unión chat grupal: $data');
      final eventData = Map<String, dynamic>.from(data);
      eventData['_eventType'] = 'group_chat_joined';
      
      _groupChatEventsStreamController.add(eventData);
      
      print('🚗✅ Confirmación unión chat grupal procesada exitosamente');
    } catch (e) {
      print('❌ Error procesando confirmación unión chat grupal: $e');
    }
  }

  // Manejar confirmación de salida del chat grupal
  void _handleGroupChatLeft(dynamic data) {
    try {
      print('🚗❌ Procesando confirmación salida chat grupal: $data');
      final eventData = Map<String, dynamic>.from(data);
      eventData['_eventType'] = 'group_chat_left';
      
      _groupChatEventsStreamController.add(eventData);
      
      print('🚗❌ Confirmación salida chat grupal procesada exitosamente');
    } catch (e) {
      print('❌ Error procesando confirmación salida chat grupal: $e');
    }
  }

  // Manejar estado del chat grupal
  void _handleGroupChatState(dynamic data) {
    try {
      print('🚗📊 Procesando estado chat grupal: $data');
      final eventData = Map<String, dynamic>.from(data);
      eventData['_eventType'] = 'group_chat_state';
      
      _groupChatEventsStreamController.add(eventData);
      
      print('🚗📊 Estado chat grupal procesado exitosamente');
    } catch (e) {
      print('❌ Error procesando estado chat grupal: $e');
    }
  }

  // Manejar chat grupal creado
  void _handleGroupChatCreated(dynamic data) {
    try {
      print('🚗🆕 Procesando chat grupal creado: $data');
      final eventData = Map<String, dynamic>.from(data);
      eventData['_eventType'] = 'group_chat_created';
      
      _groupChatEventsStreamController.add(eventData);
      
      print('🚗🆕 Chat grupal creado procesado exitosamente');
    } catch (e) {
      print('❌ Error procesando chat grupal creado: $e');
    }
  }

  // Manejar chat grupal finalizado
  void _handleGroupChatFinished(dynamic data) {
    try {
      print('🚗🏁 Procesando chat grupal finalizado: $data');
      final eventData = Map<String, dynamic>.from(data);
      eventData['_eventType'] = 'group_chat_finished';
      
      _groupChatEventsStreamController.add(eventData);
      
      print('🚗🏁 Chat grupal finalizado procesado exitosamente');
    } catch (e) {
      print('❌ Error procesando chat grupal finalizado: $e');
    }
  }

  // Manejar agregado al chat grupal
  void _handleAddedToGroupChat(dynamic data) {
    try {
      print('🚗➕ Procesando agregado al chat grupal: $data');
      final eventData = Map<String, dynamic>.from(data);
      eventData['_eventType'] = 'added_to_group_chat';
      
      _groupChatEventsStreamController.add(eventData);
      
      print('🚗➕ Agregado al chat grupal procesado exitosamente');
    } catch (e) {
      print('❌ Error procesando agregado al chat grupal: $e');
    }
  }

  // Manejar eliminado del chat grupal
  void _handleRemovedFromGroupChat(dynamic data) {
    try {
      print('🚗➖ Procesando eliminado del chat grupal: $data');
      final eventData = Map<String, dynamic>.from(data);
      eventData['_eventType'] = 'removed_from_group_chat';
      
      _groupChatEventsStreamController.add(eventData);
      
      print('🚗➖ Eliminado del chat grupal procesado exitosamente');
    } catch (e) {
      print('❌ Error procesando eliminado del chat grupal: $e');
    }
  }

  // Manejar participante agregado
  void _handleParticipantAdded(dynamic data) {
    try {
      print('🚗👥 Procesando participante agregado: $data');
      final eventData = Map<String, dynamic>.from(data);
      eventData['_eventType'] = 'participant_added';
      
      _groupParticipantsStreamController.add(eventData);
      _groupChatEventsStreamController.add(eventData);
      
      print('🚗👥 Participante agregado procesado exitosamente');
    } catch (e) {
      print('❌ Error procesando participante agregado: $e');
    }
  }

  // Manejar participante eliminado
  void _handleParticipantRemoved(dynamic data) {
    try {
      print('🚗👥 Procesando participante eliminado: $data');
      final eventData = Map<String, dynamic>.from(data);
      eventData['_eventType'] = 'participant_removed';
      
      _groupParticipantsStreamController.add(eventData);
      _groupChatEventsStreamController.add(eventData);
      
      print('🚗👥 Participante eliminado procesado exitosamente');
    } catch (e) {
      print('❌ Error procesando participante eliminado: $e');
    }
  }

  // Manejar errores de mensajes grupales
  void _handleGroupMessageError(dynamic data) {
    try {
      print('🚗❌ Procesando error de mensaje grupal: $data');
      final errorData = Map<String, dynamic>.from(data);
      final errorMessage = errorData['error']?.toString() ?? '';
      
      // Detectar error específico de permisos
      if (errorMessage.contains('No tienes permisos') || 
          errorMessage.contains('permisos para enviar mensajes')) {
        print('🚗🔧 Error de permisos detectado, emitiendo evento para re-inicialización');
        
        // Emitir evento especial que el chat grupal puede escuchar
        errorData['_eventType'] = 'permission_error';
        errorData['_needsReinitialization'] = true;
        _groupChatEventsStreamController.add(errorData);
      } else {
        // Otros errores, emitir normalmente
        errorData['_eventType'] = 'message_error';
        _groupChatEventsStreamController.add(errorData);
      }
      
      print('🚗❌ Error de mensaje grupal procesado');
    } catch (e) {
      print('❌ Error procesando error de mensaje grupal: $e');
    }
  }

  // === HANDLERS PARA PETICIONES DE SUPERVISIÓN ===

  // Manejar respuesta a petición de supervisión (para usuarios)
  void _handlePeticionSupervisionResponse(dynamic data) {
    try {
      print('📋 Procesando respuesta de petición de supervisión: $data');
      final responseData = Map<String, dynamic>.from(data);
      
      // Si la petición fue aceptada y debe abrir chat
      if (responseData['abrirChat'] == true && responseData['chatConAdministrador'] != null) {
        final chatInfo = responseData['chatConAdministrador'];
        final rutAdministrador = chatInfo['rutAdministrador'];
        final nombreAdministrador = chatInfo['nombreAdministrador'];
        
        print('📋 Petición aceptada, preparando para abrir chat con $nombreAdministrador');
        
        // Agregar información adicional para que el widget pueda manejar la apertura del chat
        responseData['_eventType'] = 'peticion_aceptada_abrir_chat';
        responseData['_rutAdministrador'] = rutAdministrador;
        responseData['_nombreAdministrador'] = nombreAdministrador;
      } else {
        responseData['_eventType'] = 'peticion_respondida';
      }
      
      // Emitir la respuesta a través del stream de eventos grupales (para reutilizar la infraestructura existente)
      _groupChatEventsStreamController.add(responseData);
      
      print('📋 Respuesta de petición procesada exitosamente');
    } catch (e) {
      print('❌ Error procesando respuesta de petición: $e');
    }
  }

  // Manejar nueva petición de supervisión (para administradores)
  void _handleNuevaPeticionSupervision(dynamic data) {
    try {
      print('📋 Procesando nueva petición de supervisión: $data');
      final peticionData = Map<String, dynamic>.from(data);
      peticionData['_eventType'] = 'nueva_peticion_supervision';
      
      // Emitir la nueva petición
      _groupChatEventsStreamController.add(peticionData);
      
      print('📋 Nueva petición de supervisión procesada exitosamente');
    } catch (e) {
      print('❌ Error procesando nueva petición de supervisión: $e');
    }
  }

  // Manejar petición solucionada
  void _handlePeticionSolucionada(dynamic data) {
    try {
      print('📋 Procesando petición solucionada: $data');
      final solucionData = Map<String, dynamic>.from(data);
      solucionData['_eventType'] = 'peticion_solucionada';
      
      // Emitir la solución
      _groupChatEventsStreamController.add(solucionData);
      
      print('📋 Petición solucionada procesada exitosamente');
    } catch (e) {
      print('❌ Error procesando petición solucionada: $e');
    }
  }

  // Callback para nuevos mensajes (mantiene compatibilidad con código existente)
  void setOnNewMessageCallback(Function(dynamic) callback) {
    _onNewMessageCallback = callback;
  }

  void removeOnNewMessageCallback() {
    _onNewMessageCallback = null;
  }

  // Desconectar del socket
  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    _connectionStreamController.add(false);
    print('🔌 Socket desconectado y limpiado');
  }

  // Verificar si está conectado
  bool get isConnected => socket?.connected == true;

  // Limpiar recursos
  void dispose() {
    disconnect();
    _messageStreamController.close();
    _connectionStreamController.close();
    _editedMessageStreamController.close();
    _deletedMessageStreamController.close();
    _groupMessageStreamController.close();
    _groupParticipantsStreamController.close();
    _groupChatEventsStreamController.close();
  }
}