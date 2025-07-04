// pagina_individual_websocket.dart - Versión completa con WebSockets

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/mensaje_model.dart';
import '../config/confGlobal.dart';
import '../services/socket_service.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  
  String? _jwtToken;
  String? _rutUsuarioAutenticadoReal;
  late SocketService _socketService;
  late StreamSubscription _messageSubscription;
  late StreamSubscription _connectionSubscription;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    print('DEBUG PaginaIndividualWebSocket: RUT del usuario autenticado: ${widget.rutUsuarioAutenticado}');
    print('DEBUG PaginaIndividualWebSocket: RUT del amigo: ${widget.rutAmigo}');

    _socketService = SocketService.instance;
    _initializarDatos();
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _connectionSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
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

    print('DEBUG: RUT Usuario Real: $_rutUsuarioAutenticadoReal');
    print('DEBUG: RUT Amigo: ${widget.rutAmigo}');
  }

  Future<void> _loadJwtToken() async {
    try {
      _jwtToken = await _storage.read(key: 'jwt_token');
      if (_jwtToken != null) {
        print('✅ Token JWT cargado correctamente');
      } else {
        print('❌ No se encontró token JWT');
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
      // Conectar al socket
      await _socketService.connect();
      
      // Escuchar cambios en la conexión
      _connectionSubscription = _socketService.connectionStream.listen((isConnected) {
        if (mounted) {
          setState(() {
            _isConnected = isConnected;
          });
          
          if (isConnected) {
            print('🔌 Socket conectado correctamente');
          } else {
            print('🔌 Socket desconectado');
          }
        }
      });
      
      // Escuchar nuevos mensajes
      _messageSubscription = _socketService.messageStream.listen((messageData) {
        _handleNewSocketMessage(messageData);
      });
      
    } catch (e) {
      print('ERROR conectando socket: $e');
    }
  }

  void _handleNewSocketMessage(Map<String, dynamic> messageData) {
    if (!mounted) return;
    
    try {
      print('📨 Procesando nuevo mensaje: $messageData');
      
      // Verificar que el mensaje es para esta conversación
      final emisorRut = messageData['emisor']['rut'];
      final receptorRut = messageData['receptor']?['rut'];
      
      bool esParaEstaConversacion = false;
      
      if (receptorRut != null) {
        // Es un mensaje 1 a 1
        esParaEstaConversacion = (emisorRut == widget.rutAmigo && receptorRut == _rutUsuarioAutenticadoReal) ||
                                (emisorRut == _rutUsuarioAutenticadoReal && receptorRut == widget.rutAmigo);
      }
      
      if (esParaEstaConversacion) {
        final nuevoMensaje = Message(
          senderRut: emisorRut,
          text: messageData['contenido'],
          timestamp: DateTime.parse(messageData['fecha']),
        );
        
        setState(() {
          // Evitar duplicados
          if (!_messages.any((m) => 
              m.senderRut == nuevoMensaje.senderRut && 
              m.text == nuevoMensaje.text && 
              m.timestamp.difference(nuevoMensaje.timestamp).abs().inSeconds < 2)) {
            _messages.add(nuevoMensaje);
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          }
        });
        
        _scrollToBottom();
        print('✅ Mensaje agregado a la conversación');
      }
    } catch (e) {
      print('ERROR procesando mensaje socket: $e');
    }
  }

  Future<void> _fetchMessages() async {
    if (_jwtToken == null) {
      print('ERROR: No hay token JWT para obtener mensajes históricos.');
      return;
    }

    try {
      final Uri requestUri = Uri.parse('${confGlobal.baseUrl}/chat/conversacion/${widget.rutAmigo}');
      print('DEBUG: Intentando GET historial de mensajes de: $requestUri');

      final response = await http.get(
        requestUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_jwtToken',
        },
      );

      print('DEBUG: Código de estado del historial: ${response.statusCode}');
      print('DEBUG: Cuerpo de la respuesta del historial: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        final List<dynamic> messagesJson = responseData;

        setState(() {
          _messages.clear();
          _messages.addAll(messagesJson.map((json) {
            return Message(
              senderRut: json['emisor']['rut'],
              text: json['contenido'],
              timestamp: DateTime.parse(json['fecha']),
            );
          }).toList());

          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });

        _scrollToBottom();
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
      print('🔌 Socket no conectado, intentando reconectar...');
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

      print('📤 Mensaje enviado via WebSocket');

    } catch (e) {
      print('ERROR enviando mensaje: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar mensaje: $e')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessage(Message message, bool isMe) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Text(
                widget.nombre[0].toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.person, size: 16, color: Colors.blue),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: Text(
                widget.nombre[0].toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.nombre,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _isConnected ? 'En línea' : 'Desconectado',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Indicador de conexión
          if (!_isConnected)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              color: Colors.orange[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.orange[800]),
                  SizedBox(width: 8),
                  Text(
                    'Sin conexión en tiempo real',
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                ],
              ),
            ),
          
          // Lista de mensajes
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No hay mensajes aún.\n¡Comienza la conversación!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderRut == _rutUsuarioAutenticadoReal;
                      return _buildMessage(message, isMe);
                    },
                  ),
          ),
          
          // Campo de entrada de mensaje
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                  ),
                ),
                SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  child: Icon(Icons.send),
                  mini: true,
                  backgroundColor: _isConnected ? Colors.blue : Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
