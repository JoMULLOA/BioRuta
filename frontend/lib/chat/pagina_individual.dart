import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Agrega este import
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/confGlobal.dart';
import '../services/socket_service.dart';
import '../services/websocket_notification_service.dart';
import '../services/location_service.dart';
import '../utils/date_utils.dart' as date_utils;
import '../widgets/reportar_usuario_dialog.dart';
import '../widgets/location_message_widget.dart';
import '../models/reporte_model.dart';

// Clase Message temporal inline para debugging
class Message {
  final int? id;
  final String senderRut;
  final String text;
  final DateTime timestamp;
  final bool isEdited;
  final bool isDeleted;
  final String type; // 'text' o 'location'
  final Map<String, dynamic>? locationData; // Para mensajes de ubicación

  Message({
    this.id,
    required this.senderRut,
    required this.text,
    required this.timestamp,
    this.isEdited = false,
    this.isDeleted = false,
    this.type = 'text',
    this.locationData,
  });

  // Crear copia del mensaje con cambios
  Message copyWith({
    int? id,
    String? senderRut,
    String? text,
    DateTime? timestamp,
    bool? isEdited,
    bool? isDeleted,
    String? type,
    Map<String, dynamic>? locationData,
  }) {
    return Message(
      id: id ?? this.id,
      senderRut: senderRut ?? this.senderRut,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      type: type ?? this.type,
      locationData: locationData ?? this.locationData,
    );
  }
  
  // Factory constructor para crear mensaje de ubicación
  factory Message.location({
    required String senderRut,
    required double latitude,
    required double longitude,
    int? id,
  }) {
    return Message(
      id: id,
      senderRut: senderRut,
      text: 'Ubicación compartida',
      timestamp: DateTime.now(),
      type: 'location',
      locationData: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }
}

class PaginaIndividualWebSocket extends StatefulWidget {
  final String nombre;
  final String rutAmigo;
  final String? rutUsuarioAutenticado;

  const PaginaIndividualWebSocket({
    Key? key,
    required this.nombre,
    required this.rutAmigo,
    this.rutUsuarioAutenticado,
  }) : super(key: key);

  @override
  _PaginaIndividualWebSocketState createState() => _PaginaIndividualWebSocketState();
}

class _PaginaIndividualWebSocketState extends State<PaginaIndividualWebSocket> {


  void _copyMessageToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensaje copiado al portapapeles'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();
  
  String? _jwtToken;
  String? _rutUsuarioAutenticadoReal;
  late SocketService _socketService;
  late StreamSubscription<Map<String, dynamic>> _messageSubscription;
  late StreamSubscription<Map<String, dynamic>> _editedMessageSubscription;
  late StreamSubscription<Map<String, dynamic>> _deletedMessageSubscription;
  late StreamSubscription<bool> _connectionSubscription;
  late StreamSubscription<Map<String, dynamic>> _peticionSolucionadaSubscription;
  bool _isConnected = false;
  
  // Para edición de mensajes
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('[CHAT] 🚀 INICIANDO CHAT INDIVIDUAL - initState()');
    _socketService = SocketService.instance;
    _initializarDatos();
    print('[CHAT] 🚀 CHAT INDIVIDUAL INICIADO COMPLETAMENTE');
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _editedMessageSubscription.cancel();
    _deletedMessageSubscription.cancel();
    _connectionSubscription.cancel();
    _peticionSolucionadaSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _initializarDatos() async {
    // Obtener el RUT del usuario autenticado
    _rutUsuarioAutenticadoReal = widget.rutUsuarioAutenticado ?? await _storage.read(key: 'user_rut');
    
    // Cargar el token JWT
    await _loadJwtToken();
    
    // Conectar al socket
    await _connectSocket();
    
    // Cargar mensajes históricos
    await _fetchMessages();
  }

  Future<void> _loadJwtToken() async {
    try {
      _jwtToken = await _storage.read(key: 'jwt_token');
      if (_jwtToken != null) {
        print('Token JWT cargado correctamente');
      } else {
        print('No se encontró token JWT');
      }
    } catch (e) {
      print('ERROR cargando token: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se pudo cargar el token de autenticación.')),
        );
      }
    }
  }

  Future<void> _connectSocket() async {
    try {
      await _socketService.connect();
      
      setState(() {
        _isConnected = _socketService.isConnected;
      });
      
      // Escuchar cambios en la conexión
      _connectionSubscription = _socketService.connectionStream.listen((isConnected) {
        if (mounted) {
          setState(() {
            _isConnected = isConnected;
          });
        }
      });
      
      // Escuchar nuevos mensajes
      _messageSubscription = _socketService.messageStream.listen((messageData) {
        if (messageData['_isEdited'] == true) {
          _handleEditedMessage(messageData);
        } else if (messageData['_isDeleted'] == true) {
          _handleDeletedMessage(messageData);
        } else {
          _handleNewSocketMessage(messageData);
        }
      });

      // Escuchar mensajes editados específicamente
      _editedMessageSubscription = _socketService.editedMessageStream.listen((messageData) {
        print('📝 Escuchando mensaje editado desde stream específico: $messageData');
        _handleEditedMessage(messageData);
      });

      // Escuchar mensajes eliminados específicamente
      _deletedMessageSubscription = _socketService.deletedMessageStream.listen((messageData) {
        print('🗑️ Escuchando mensaje eliminado desde stream específico: $messageData');
        _handleDeletedMessage(messageData);
      });

      // Escuchar notificaciones de peticiones solucionadas
      _peticionSolucionadaSubscription = _socketService.groupChatEventsStream.listen((data) {
        final eventType = data['_eventType'];
        if (eventType == 'peticion_solucionada') {
          _manejarPeticionSolucionada(data);
        }
      });

      // Escuchar confirmaciones y errores de WebSocket
      _socketService.socket?.on('edicion_exitosa', (data) {
        print('✅ Confirmación de edición recibida: $data');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mensaje editado correctamente')),
          );
        }
      });

      _socketService.socket?.on('eliminacion_exitosa', (data) {
        print('✅ Confirmación de eliminación recibida: $data');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mensaje eliminado correctamente')),
          );
        }
      });

      _socketService.socket?.on('error_edicion', (data) {
        print('❌ Error de edición recibido: $data');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al editar: ${data['error'] ?? 'Error desconocido'}')),
          );
        }
      });

      _socketService.socket?.on('error_eliminacion', (data) {
        print('❌ Error de eliminación recibido: $data');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: ${data['error'] ?? 'Error desconocido'}')),
          );
        }
      });
      
    } catch (e) {
      print('ERROR conectando socket: $e');
    }
  }

  void _handleNewSocketMessage(Map<String, dynamic> messageData) {
    if (!mounted) return;
    
    try {
      // Si es un mensaje editado o eliminado, no procesar aquí
      if (messageData['_isEdited'] == true || messageData['_isDeleted'] == true) {
        return;
      }
      
      // Verificar que el mensaje es para esta conversación
      final emisorRut = messageData['emisor'];
      final receptorRut = messageData['receptor'];
      
      String emisorRutString = emisorRut.toString();
      String? receptorRutString = receptorRut?.toString();
      
      bool esParaEstaConversacion = false;
      
      if (receptorRutString != null) {
        // Es un mensaje 1 a 1
        esParaEstaConversacion = (emisorRutString == widget.rutAmigo && receptorRutString == _rutUsuarioAutenticadoReal) ||
                                (emisorRutString == _rutUsuarioAutenticadoReal && receptorRutString == widget.rutAmigo);
      }
      
      if (esParaEstaConversacion) {
        final contenido = messageData['contenido'].toString();
        String tipoMensaje = 'text';
        Map<String, dynamic>? locationData;
        
        // Verificar si es un mensaje de ubicación
        try {
          final parsedContent = json.decode(contenido);
          if (parsedContent is Map<String, dynamic> && parsedContent['type'] == 'location') {
            tipoMensaje = 'location';
            locationData = {
              'latitude': parsedContent['latitude'],
              'longitude': parsedContent['longitude'],
              'accuracy': parsedContent['accuracy'],
              'timestamp': parsedContent['timestamp'],
            };
          }
        } catch (e) {
          // No es JSON válido, es un mensaje de texto normal
        }
        
        // Crear mensaje usando el constructor directo con conversión correcta
        final nuevoMensaje = Message(
          id: messageData['id'] is String ? int.tryParse(messageData['id']) : messageData['id'],
          senderRut: messageData['emisor'].toString(),
          text: tipoMensaje == 'location' ? 'Ubicación compartida' : contenido,
          timestamp: DateTime.parse(messageData['fecha']),
          isEdited: messageData['editado'] ?? false,
          isDeleted: messageData['eliminado'] ?? false,
          type: tipoMensaje,
          locationData: locationData,
        );
        
        setState(() {
          // Evitar duplicados
          if (!_messages.any((m) => 
              m.id == nuevoMensaje.id ||
              (m.senderRut == nuevoMensaje.senderRut && 
               m.text == nuevoMensaje.text && 
               m.timestamp.difference(nuevoMensaje.timestamp).abs().inSeconds < 2))) {
            _messages.add(nuevoMensaje);
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            
            // Mostrar notificación solo si el mensaje lo envió el otro usuario
            if (nuevoMensaje.senderRut != _rutUsuarioAutenticadoReal && !nuevoMensaje.isDeleted) {
              print('[CHAT] 🔍 VERIFICANDO CONDICIONES DE NOTIFICACIÓN:');
              print('[CHAT] 📧 Emisor del mensaje: ${nuevoMensaje.senderRut}');
              print('[CHAT] 👤 Usuario autenticado: $_rutUsuarioAutenticadoReal');
              print('[CHAT] ❌ Mensaje eliminado: ${nuevoMensaje.isDeleted}');
              print('[CHAT] ✅ CONDICIONES CUMPLIDAS - Mensaje recibido de otro usuario, mostrando notificación...');
              
              // 🔔 LLAMADA AL SERVICIO DE NOTIFICACIONES
              print('[CHAT] 🔔 ENVIANDO NOTIFICACIÓN AL SERVICIO...');
              WebSocketNotificationService.showLocalNotification(
                title: '💬 ${widget.nombre}',
                body: nuevoMensaje.text,
                payload: 'chat_individual_${widget.rutAmigo}',
              );
              print('[CHAT] 🔔 NOTIFICACIÓN ENVIADA AL SERVICIO EXITOSAMENTE');
            } else {
              print('[CHAT] ❌ NO MOSTRAR NOTIFICACIÓN:');
              print('[CHAT] 📧 Emisor del mensaje: ${nuevoMensaje.senderRut}');
              print('[CHAT] 👤 Usuario autenticado: $_rutUsuarioAutenticadoReal');
              print('[CHAT] 🗑️ Mensaje eliminado: ${nuevoMensaje.isDeleted}');
              print('[CHAT] 📝 Es mi propio mensaje o mensaje eliminado');
              print('[CHAT] ⚠️  USUARIOS IGUALES = ${nuevoMensaje.senderRut == _rutUsuarioAutenticadoReal}');
            }
          }
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      print('ERROR procesando nuevo mensaje: $e');
    }
  }

  void _handleEditedMessage(Map<String, dynamic> messageData) {
    if (!mounted) return;
    
    try {
      print('📝 DEBUG: Procesando mensaje editado: $messageData');
      
      // Buscar ID del mensaje
      dynamic messageIdDynamic = messageData['id'] ?? messageData['idMensaje'];
      final newContent = messageData['contenido'] ?? messageData['nuevoContenido'];
      
      int? messageId;
      if (messageIdDynamic is int) {
        messageId = messageIdDynamic;
      } else if (messageIdDynamic is String) {
        messageId = int.tryParse(messageIdDynamic);
      }
      
      if (messageId == null || newContent == null) {
        print('📝 ERROR: Datos incompletos - ID: $messageIdDynamic, Contenido: $newContent');
        return;
      }
      
      print('📝 DEBUG: Actualizando mensaje ID=$messageId con contenido="$newContent"');
      
      // Buscar y actualizar el mensaje directamente sin verificación de conversación
      // (ya que el backend solo envía eventos a usuarios relevantes)
      setState(() {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            text: newContent.toString(),
            isEdited: true,
          );
          print('📝 SUCCESS: Mensaje actualizado en posición $index');
        } else {
          print('📝 WARNING: Mensaje no encontrado localmente, ID=$messageId');
        }
      });
      
    } catch (e) {
      print('📝 ERROR procesando mensaje editado: $e');
    }
  }

  void _handleDeletedMessage(Map<String, dynamic> messageData) {
    if (!mounted) return;
    
    try {
      print('🗑️ DEBUG: Procesando mensaje eliminado: $messageData');
      
      // Buscar ID del mensaje
      dynamic messageIdDynamic = messageData['id'] ?? messageData['idMensaje'];
      
      int? messageId;
      if (messageIdDynamic is int) {
        messageId = messageIdDynamic;
      } else if (messageIdDynamic is String) {
        messageId = int.tryParse(messageIdDynamic);
      }
      
      if (messageId == null) {
        print('🗑️ ERROR: No se pudo obtener ID del mensaje: $messageIdDynamic');
        return;
      }
      
      print('🗑️ DEBUG: Eliminando mensaje ID=$messageId');
      
      // Buscar y actualizar el mensaje directamente
      setState(() {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            text: "Mensaje eliminado",
            isDeleted: true,
          );
          print('🗑️ SUCCESS: Mensaje marcado como eliminado en posición $index');
        } else {
          print('🗑️ WARNING: Mensaje no encontrado localmente, ID=$messageId');
        }
      });
      
    } catch (e) {
      print('🗑️ ERROR procesando mensaje eliminado: $e');
    }
  }

  Future<void> _fetchMessages() async {
    if (_jwtToken == null) {
      print('ERROR: No hay token JWT para obtener mensajes históricos.');
      return;
    }

    try {
      final Uri requestUri = Uri.parse('${confGlobal.baseUrl}/chat/conversacion/${widget.rutAmigo}');
      
      final response = await http.get(
        requestUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_jwtToken',
        },
      );

      if (response.statusCode == 200) {
        try {
          final List<dynamic> responseData = json.decode(response.body);
          final List<Message> newMessages = [];
          
          for (int i = 0; i < responseData.length; i++) {
            try {
              final messageData = responseData[i] as Map<String, dynamic>;
              
              // Convertir id de manera segura
              int? messageId;
              if (messageData['id'] is String) {
                messageId = int.tryParse(messageData['id']);
              } else if (messageData['id'] is int) {
                messageId = messageData['id'];
              }
              
              // Crear mensaje
              final contenido = messageData['contenido'].toString();
              String tipoMensaje = 'text';
              Map<String, dynamic>? locationData;
              
              // Verificar si es un mensaje de ubicación
              try {
                final parsedContent = json.decode(contenido);
                if (parsedContent is Map<String, dynamic> && parsedContent['type'] == 'location') {
                  tipoMensaje = 'location';
                  locationData = {
                    'latitude': parsedContent['latitude'],
                    'longitude': parsedContent['longitude'],
                    'accuracy': parsedContent['accuracy'],
                    'timestamp': parsedContent['timestamp'],
                  };
                }
              } catch (e) {
                // No es JSON válido, es un mensaje de texto normal
              }
              
              final message = Message(
                id: messageId,
                senderRut: messageData['emisor'].toString(),
                text: tipoMensaje == 'location' ? 'Ubicación compartida' : contenido,
                timestamp: DateTime.parse(messageData['fecha']),
                isEdited: messageData['editado'] ?? false,
                isDeleted: messageData['eliminado'] ?? false,
                type: tipoMensaje,
                locationData: locationData,
              );
              
              newMessages.add(message);
            } catch (e) {
              print('Error procesando mensaje $i: $e');
              continue;
            }
          }

          setState(() {
            _messages.clear();
            _messages.addAll(newMessages);
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          });

          _scrollToBottom();
          
        } catch (e) {
          print('Error procesando respuesta del historial: $e');
        }
      } else {
        print('ERROR al obtener historial: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('ERROR de conexión al obtener historial: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    // Validar que tenemos el RUT del usuario autenticado
    if (_rutUsuarioAutenticadoReal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se pudo identificar el usuario para enviar el mensaje.')),
      );
      return;
    }

    final String messageText = _messageController.text.trim();
    _messageController.clear();

    // Verificar que el socket esté conectado
    if (!_socketService.isConnected) {
      await _socketService.connect();
      
      if (!_socketService.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión. Intenta nuevamente.')),
        );
        return;
      }
    }

    try {
      // Enviar mensaje via WebSocket
      _socketService.sendMessage(
        contenido: messageText,
        receptorRut: widget.rutAmigo,
      );

    } catch (e) {
      print('ERROR enviando mensaje: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar mensaje: $e')),
      );
    }
  }

  /// Enviar ubicación actual
  Future<void> _sendLocation() async {
    // Validar que tenemos el RUT del usuario autenticado
    if (_rutUsuarioAutenticadoReal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se pudo identificar el usuario para enviar la ubicación.')),
      );
      return;
    }

    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Obteniendo ubicación...'),
          ],
        ),
      ),
    );

    try {
      // Obtener ubicación actual
      final locationData = await LocationService.getCurrentLocation();
      
      // Cerrar diálogo de carga
      Navigator.of(context).pop();
      
      if (locationData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la ubicación. Verifica los permisos.')),
        );
        return;
      }

      // Verificar que el socket esté conectado
      if (!_socketService.isConnected) {
        await _socketService.connect();
        
        if (!_socketService.isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error de conexión. Intenta nuevamente.')),
          );
          return;
        }
      }

      // Crear mensaje de ubicación
      final locationMessage = {
        'type': 'location',
        'latitude': locationData['latitude'],
        'longitude': locationData['longitude'],
        'accuracy': locationData['accuracy'],
        'timestamp': locationData['timestamp'],
      };

      // Enviar mensaje de ubicación via WebSocket
      _socketService.sendMessage(
        contenido: json.encode(locationMessage),
        receptorRut: widget.rutAmigo,
      );

      print('✅ Ubicación enviada: ${locationData['latitude']}, ${locationData['longitude']}');
      
    } catch (e) {
      // Cerrar diálogo si aún está abierto
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      print('❌ Error enviando ubicación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar ubicación: $e')),
      );
    }
  }

  // Función para buscar mensajes
  Future<void> _searchMessages(String query) async {
    if (_jwtToken == null || query.trim().isEmpty) return;

    try {
      final Uri requestUri = Uri.parse('${confGlobal.baseUrl}/chat/conversacion/${widget.rutAmigo}/buscar?q=${Uri.encodeComponent(query)}');
      
      final response = await http.get(
        requestUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        _showSearchResults(results, query);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error buscando mensajes: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('ERROR buscando mensajes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al buscar mensajes: $e')),
      );
    }
  }

  void _showSearchResults(List<dynamic> results, String query) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resultados para "$query"'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: results.isEmpty
              ? const Center(child: Text('No se encontraron mensajes'))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final json = results[index];
                    return ListTile(
                      title: Text(json['contenido']),
                      subtitle: Text(
                        '${json['emisor'] == _rutUsuarioAutenticadoReal ? "Tú" : widget.nombre} - ${date_utils.DateUtils.obtenerFechaChile(DateTime.parse(json['fecha']))}',
                      ),
                      dense: true,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // Función para editar mensaje (usando WebSocket)
  void _editMessage(int messageId, String newContent) {
    // Verificar que el socket esté conectado
    if (!_socketService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión. Intenta nuevamente.')),
      );
      return;
    }

    print('📝 Enviando edición via WebSocket: ID=$messageId, Contenido=$newContent');
    
    // Usar WebSocket para editar mensaje (instantáneo)
    _socketService.editMessage(
      idMensaje: messageId,
      nuevoContenido: newContent,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Editando mensaje...')),
    );
  }

  // Función para eliminar mensaje (usando WebSocket)
  void _deleteMessage(int messageId) {
    // Verificar que el socket esté conectado
    if (!_socketService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión. Intenta nuevamente.')),
      );
      return;
    }

    print('🗑️ Enviando eliminación via WebSocket: ID=$messageId');
    
    // Usar WebSocket para eliminar mensaje (instantáneo)
    _socketService.deleteMessage(
      idMensaje: messageId,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Eliminando mensaje...')),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF854937),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                widget.nombre.isNotEmpty ? widget.nombre[0] : '?',
                style: const TextStyle(color: Color(0xFF854937)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.nombre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _isConnected ? 'En línea' : 'Desconectado',
                    style: TextStyle(
                      color: _isConnected ? Colors.white70 : Colors.white70,
                      fontSize: 12,
                      fontWeight: _isConnected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Botón de prueba de notificaciones
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.amber),
            onPressed: () async {
              print('[CHAT] 🧪 PRUEBA DE NOTIFICACIÓN INICIADA');
              WebSocketNotificationService.showLocalNotification(
                title: '🧪 Usuario de Prueba',
                body: 'Esta es una notificación de prueba del chat individual',
                payload: 'test_chat_individual',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notificación de prueba enviada usando el servicio existente'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Buscar mensajes'),
                  content: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe lo que quieres buscar...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (query) {
                      Navigator.pop(context);
                      _searchMessages(query);
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _searchMessages(_searchController.text);
                      },
                      child: const Text('Buscar'),
                    ),
                  ],
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (String value) {
              switch (value) {
                case 'reportar':
                  _mostrarDialogoReporte();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'reportar',
                child: Row(
                  children: [
                    Icon(Icons.report, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Reportar usuario'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.senderRut == _rutUsuarioAutenticadoReal;

                // Si es un mensaje de ubicación, usar el widget especializado
                if (message.type == 'location' && message.locationData != null) {
                  return LocationMessageWidget(
                    latitude: message.locationData!['latitude'],
                    longitude: message.locationData!['longitude'],
                    senderName: isMe ? 'Tú' : widget.nombre,
                    timestamp: message.timestamp,
                    isOwnMessage: isMe,
                  );
                }

                // Mensaje de texto normal
                final cafeClaro = const Color(0xFFD7BFAE); // Café claro para mensaje propio
                final cafeOscuro = const Color(0xFF854937); // Café oscuro para globo 'Tú'
                final colorMensaje = isMe ? cafeClaro : Colors.grey[300];
                final colorTextoMensaje = isMe ? Colors.black : Colors.black;
                final colorHora = isMe ? Colors.black54 : Colors.black54;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!isMe) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: cafeOscuro,
                          child: Text(
                            widget.nombre.isNotEmpty ? widget.nombre[0] : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: GestureDetector(
                          onLongPress: isMe ? () => _showMessageOptions(message) : null,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorMensaje,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.isDeleted ? "Mensaje eliminado" : message.text,
                                  style: TextStyle(
                                    color: colorTextoMensaje,
                                    fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      date_utils.DateUtils.obtenerHoraChile(message.timestamp),
                                      style: TextStyle(
                                        color: colorHora,
                                        fontSize: 10,
                                      ),
                                    ),
                                    if (message.isEdited) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '(editado)',
                                        style: TextStyle(
                                          color: colorHora,
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: cafeOscuro,
                          child: const Text(
                            'Tú',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Botón de ubicación
                IconButton(
                  onPressed: _sendLocation,
                  icon: const Icon(Icons.location_on),
                  color: const Color(0xFF854937),
                  tooltip: 'Compartir ubicación',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: const Color(0xFF854937),
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Message message) {
    if (message.isDeleted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiar'),
              onTap: () {
                Navigator.pop(context);
                _copyMessageToClipboard(message.text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar mensaje'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Eliminar mensaje'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Message message) {
    _editController.text = message.text;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar mensaje'),
        content: TextField(
          controller: _editController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Nuevo texto del mensaje',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_editController.text.trim().isNotEmpty && message.id != null) {
                _editMessage(message.id!, _editController.text.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar mensaje'),
        content: const Text('¿Estás seguro de que quieres eliminar este mensaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (message.id != null) {
                _deleteMessage(message.id!);
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _manejarPeticionSolucionada(Map<String, dynamic> data) {
    if (!mounted) return;

    print('✅ Petición solucionada detectada en chat individual: $data');
    
    // Mostrar un diálogo informativo antes de redirigir
    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando fuera
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.blue, size: 28),
              SizedBox(width: 8),
              Text('Sesión Finalizada'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '✅ Tu petición de supervisión ha sido marcada como solucionada.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gracias por usar nuestro servicio de soporte. Serás redirigido al chat de soporte.',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar diálogo
                _regresarAlChatSoporte();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.support_agent, size: 18),
                  SizedBox(width: 4),
                  Text('Ir al Soporte'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _regresarAlChatSoporte() {
    // Cerrar el chat individual y regresar al chat de soporte
    Navigator.of(context).pop(); // Esto cierra la pantalla actual y regresa a la anterior
    
    // Mostrar notificación final
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Has regresado al chat de soporte. Puedes crear una nueva petición si necesitas ayuda.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _mostrarDialogoReporte() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReportarUsuarioDialog(
          usuarioReportado: widget.rutAmigo,
          nombreUsuario: widget.nombre,
          tipoReporte: TipoReporte.chatIndividual,
        );
      },
    );
  }
}
