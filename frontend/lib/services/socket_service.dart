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
  
  // Getters para los streams
  Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;
  Stream<bool> get connectionStream => _connectionStreamController.stream;
  
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
        _handleEditedMessage(data);
      });

      // Escuchar mensaje eliminado
      socket!.on('mensaje_eliminado', (data) {
        print('🗑️ Mensaje eliminado recibido: $data');
        _handleDeletedMessage(data);
      });

      // Escuchar confirmación de mensaje enviado
      socket!.on('mensaje_enviado', (data) {
        print('✅ Mensaje enviado confirmado: $data');
      });

      // Escuchar errores de mensaje
      socket!.on('error_mensaje', (data) {
        print('❌ Error de mensaje: $data');
      });

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
      final messageData = Map<String, dynamic>.from(data);
      messageData['_isEdited'] = true; // Marcar como editado
      
      // Emitir a través del stream
      _messageStreamController.add(messageData);
      
      // Mantener compatibilidad con callback
      if (_onNewMessageCallback != null) {
        _onNewMessageCallback!(data);
      }
    } catch (e) {
      print('❌ Error procesando mensaje editado: $e');
    }
  }

  // Manejar mensajes eliminados
  void _handleDeletedMessage(dynamic data) {
    try {
      final messageData = Map<String, dynamic>.from(data);
      messageData['_isDeleted'] = true; // Marcar como eliminado
      
      // Emitir a través del stream
      _messageStreamController.add(messageData);
      
      // Mantener compatibilidad con callback
      if (_onNewMessageCallback != null) {
        _onNewMessageCallback!(data);
      }
    } catch (e) {
      print('❌ Error procesando mensaje eliminado: $e');
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
  }
}