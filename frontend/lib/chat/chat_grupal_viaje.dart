import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../utils/date_utils.dart' as date_utils;

// Clase Message para chat grupal
class GroupMessage {
  final int? id;
  final String senderRut;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isEdited;
  final bool isDeleted;
  final String idViajeMongo;

  GroupMessage({
    this.id,
    required this.senderRut,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isEdited = false,
    this.isDeleted = false,
    required this.idViajeMongo,
  });

  // Crear copia del mensaje con cambios
  GroupMessage copyWith({
    int? id,
    String? senderRut,
    String? senderName,
    String? text,
    DateTime? timestamp,
    bool? isEdited,
    bool? isDeleted,
    String? idViajeMongo,
  }) {
    return GroupMessage(
      id: id ?? this.id,
      senderRut: senderRut ?? this.senderRut,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      idViajeMongo: idViajeMongo ?? this.idViajeMongo,
    );
  }

  // Crear desde JSON
  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    return GroupMessage(
      id: json['id'],
      senderRut: json['emisor'] ?? json['senderRut'],
      senderName: json['emisorNombre'] ?? json['senderName'] ?? 'Usuario',
      text: json['contenido'] ?? json['text'],
      timestamp: json['fecha'] != null 
          ? DateTime.parse(json['fecha'])
          : DateTime.now(),
      isEdited: json['editado'] ?? false,
      isDeleted: json['eliminado'] ?? false,
      idViajeMongo: json['idViajeMongo'],
    );
  }
}

class ChatGrupalViaje extends StatefulWidget {
  final String idViaje;
  final String nombreViaje;
  final List<String> participantes;
  final String? rutUsuarioAutenticado;

  const ChatGrupalViaje({
    Key? key,
    required this.idViaje,
    required this.nombreViaje,
    required this.participantes,
    this.rutUsuarioAutenticado,
  }) : super(key: key);

  @override
  _ChatGrupalViajeState createState() => _ChatGrupalViajeState();
}

class _ChatGrupalViajeState extends State<ChatGrupalViaje> {
  final TextEditingController _messageController = TextEditingController();
  final List<GroupMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  
  String? _jwtToken;
  String? _rutUsuarioAutenticadoReal;
  late SocketService _socketService;
  late StreamSubscription<Map<String, dynamic>> _messageSubscription;
  late StreamSubscription<Map<String, dynamic>> _editedMessageSubscription;
  late StreamSubscription<Map<String, dynamic>> _deletedMessageSubscription;
  late StreamSubscription<bool> _connectionSubscription;
  bool _isConnected = false;
  
  // Para edición de mensajes
  final TextEditingController _editController = TextEditingController();
  GroupMessage? _editingMessage;

  @override
  void initState() {
    super.initState();
    _socketService = SocketService.instance;
    _initializarDatos();
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _editedMessageSubscription.cancel();
    _deletedMessageSubscription.cancel();
    _connectionSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
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
    
    // Unirse al chat del viaje
    _socketService.joinViajeChat(widget.idViaje);
    
    // Cargar mensajes históricos
    await _fetchGroupMessages();
  }

  Future<void> _loadJwtToken() async {
    try {
      _jwtToken = await _storage.read(key: 'jwt_token');
      if (_jwtToken != null) {
        print('Token JWT cargado correctamente para chat grupal');
      } else {
        print('No se encontró token JWT para chat grupal');
      }
    } catch (e) {
      print('ERROR cargando token para chat grupal: $e');
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
      
      // Escuchar nuevos mensajes grupales
      _messageSubscription = _socketService.messageStream.listen((messageData) {
        print('🔍 DEBUG: Mensaje recibido en chat grupal: $messageData');
        
        // Verificar si es un mensaje grupal para este viaje
        if (messageData['idViajeMongo'] == widget.idViaje || 
            messageData['tipo'] == 'grupal') {
          _handleNewGroupMessage(messageData);
        }
      });
      
      // Escuchar mensajes editados
      _editedMessageSubscription = _socketService.editedMessageStream.listen((messageData) {
        print('🔍 DEBUG: Mensaje editado recibido en chat grupal: $messageData');
        
        if (messageData['idViajeMongo'] == widget.idViaje || 
            messageData['tipo'] == 'grupal') {
          _handleEditedGroupMessage(messageData);
        }
      });
      
      // Escuchar mensajes eliminados
      _deletedMessageSubscription = _socketService.deletedMessageStream.listen((messageData) {
        print('🔍 DEBUG: Mensaje eliminado recibido en chat grupal: $messageData');
        
        if (messageData['tipo'] == 'grupal') {
          _handleDeletedGroupMessage(messageData);
        }
      });

    } catch (e) {
      print('❌ Error conectando socket para chat grupal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error conectando al chat: $e')),
        );
      }
    }
  }

  Future<void> _fetchGroupMessages() async {
    // TODO: Implementar carga de mensajes históricos del viaje
    // Por ahora dejamos vacío, los mensajes llegarán via WebSocket
    print('📥 Cargando mensajes históricos para viaje ${widget.idViaje}');
  }

  void _handleNewGroupMessage(Map<String, dynamic> messageData) {
    try {
      print('📨 Procesando nuevo mensaje grupal: $messageData');
      
      final message = GroupMessage.fromJson(messageData);
      
      if (mounted) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('❌ Error procesando nuevo mensaje grupal: $e');
    }
  }

  void _handleEditedGroupMessage(Map<String, dynamic> messageData) {
    try {
      print('✏️ Procesando mensaje grupal editado: $messageData');
      
      final messageId = messageData['id'];
      final newContent = messageData['contenido'];
      
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((msg) => msg.id == messageId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              text: newContent,
              isEdited: true,
            );
          }
        });
      }
    } catch (e) {
      print('❌ Error procesando mensaje grupal editado: $e');
    }
  }

  void _handleDeletedGroupMessage(Map<String, dynamic> messageData) {
    try {
      print('🗑️ Procesando mensaje grupal eliminado: $messageData');
      
      final messageId = messageData['idMensaje'];
      
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((msg) => msg.id == messageId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              isDeleted: true,
              text: "[Mensaje eliminado]",
            );
          }
        });
      }
    } catch (e) {
      print('❌ Error procesando mensaje grupal eliminado: $e');
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || !_isConnected) return;

    final content = _messageController.text.trim();
    _messageController.clear();

    // Enviar mensaje grupal via socket
    _socketService.sendMessage(
      contenido: content,
      receptorRut: '', // Para grupos no se usa
      idViajeMongo: widget.idViaje,
    );

    _scrollToBottom();
  }

  void _editMessage(GroupMessage message) {
    setState(() {
      _editingMessage = message;
      _editController.text = message.text;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar mensaje'),
        content: TextField(
          controller: _editController,
          decoration: const InputDecoration(
            hintText: 'Nuevo contenido del mensaje',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _editingMessage = null;
              });
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (_editController.text.trim().isNotEmpty && _editingMessage != null) {
                _socketService.editGroupMessage(
                  idMensaje: _editingMessage!.id!,
                  nuevoContenido: _editController.text.trim(),
                  idViaje: widget.idViaje,
                );
              }
              setState(() {
                _editingMessage = null;
              });
              Navigator.of(context).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(GroupMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar mensaje'),
        content: const Text('¿Estás seguro de que quieres eliminar este mensaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              _socketService.deleteGroupMessage(
                idMensaje: message.id!,
                idViaje: widget.idViaje,
              );
              Navigator.of(context).pop();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(GroupMessage message) {
    final isMe = message.senderRut == _rutUsuarioAutenticadoReal;
    
    if (message.isDeleted) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[200],
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(
                    message.senderName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                GestureDetector(
                  onLongPress: isMe && message.id != null ? () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit),
                              title: const Text('Editar'),
                              onTap: () {
                                Navigator.pop(context);
                                _editMessage(message);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete),
                              title: const Text('Eliminar'),
                              onTap: () {
                                Navigator.pop(context);
                                _deleteMessage(message);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  } : null,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue[500] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (message.isEdited)
                          Text(
                            '(editado)',
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white70 : Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Text(
                  date_utils.DateUtils.obtenerHoraChile(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green[200],
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : 'Y',
                style: const TextStyle(fontSize: 12),
              ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.nombreViaje),
            Text(
              '${widget.participantes.length} participantes',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isConnected ? Icons.wifi : Icons.wifi_off),
            onPressed: null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Lista de mensajes
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          
          // Campo de entrada de mensajes
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                  color: Colors.grey.withOpacity(0.3),
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
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _isConnected ? _sendMessage : null,
                  mini: true,
                  backgroundColor: _isConnected ? Colors.blue[600] : Colors.grey,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
