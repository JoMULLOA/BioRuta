import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/confGlobal.dart';
import '../services/socket_service.dart';

// Clase Message temporal inline para debugging
class Message {
  final int? id;
  final String senderRut;
  final String text;
  final DateTime timestamp;
  final bool isEdited;
  final bool isDeleted;

  Message({
    this.id,
    required this.senderRut,
    required this.text,
    required this.timestamp,
    this.isEdited = false,
    this.isDeleted = false,
  });

  // Crear copia del mensaje con cambios
  Message copyWith({
    int? id,
    String? senderRut,
    String? text,
    DateTime? timestamp,
    bool? isEdited,
    bool? isDeleted,
  }) {
    return Message(
      id: id ?? this.id,
      senderRut: senderRut ?? this.senderRut,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
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
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();
  
  String? _jwtToken;
  String? _rutUsuarioAutenticadoReal;
  late SocketService _socketService;
  late StreamSubscription<Map<String, dynamic>> _messageSubscription;
  late StreamSubscription<bool> _connectionSubscription;
  bool _isConnected = false;
  
  // Para edición de mensajes
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _socketService = SocketService.instance;
    _initializarDatos();
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _connectionSubscription.cancel();
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
        // Crear mensaje usando el constructor directo con conversión correcta
        final nuevoMensaje = Message(
          id: messageData['id'] is String ? int.tryParse(messageData['id']) : messageData['id'],
          senderRut: messageData['emisor'].toString(),
          text: messageData['contenido'].toString(),
          timestamp: DateTime.parse(messageData['fecha']),
          isEdited: messageData['editado'] ?? false,
          isDeleted: messageData['eliminado'] ?? false,
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
      // Buscar ID del mensaje - puede venir como 'id' o 'idMensaje'
      final messageId = messageData['id'] is String ? int.tryParse(messageData['id']) : messageData['id'] ??
                        messageData['idMensaje'] is String ? int.tryParse(messageData['idMensaje']) : messageData['idMensaje'];
      final newContent = messageData['contenido'] ?? messageData['nuevoContenido'];
      
      if (messageId == null) {
        return;
      }
      
      // Verificar si el mensaje pertenece a esta conversación
      final emisorRut = messageData['emisor']?.toString();
      final receptorRut = messageData['receptor']?.toString();
      
      bool esParaEstaConversacion = false;
      if (emisorRut != null && receptorRut != null) {
        esParaEstaConversacion = (emisorRut == widget.rutAmigo && receptorRut == _rutUsuarioAutenticadoReal) ||
                                (emisorRut == _rutUsuarioAutenticadoReal && receptorRut == widget.rutAmigo);
      }
      
      if (!esParaEstaConversacion) {
        return;
      }
      
      setState(() {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            text: newContent,
            isEdited: true,
          );
        } else {
          _reloadMessages();
        }
      });
      
    } catch (e) {
      print('ERROR procesando mensaje editado: $e');
    }
  }

  void _handleDeletedMessage(Map<String, dynamic> messageData) {
    if (!mounted) return;
    
    try {
      // Buscar ID del mensaje - puede venir como 'id' o 'idMensaje'
      final messageId = messageData['id'] is String ? int.tryParse(messageData['id']) : messageData['id'] ??
                        messageData['idMensaje'] is String ? int.tryParse(messageData['idMensaje']) : messageData['idMensaje'];
      
      if (messageId == null) {
        return;
      }
      
      // Verificar si el mensaje pertenece a esta conversación
      final emisorRut = messageData['emisor']?.toString();
      final receptorRut = messageData['receptor']?.toString();
      
      bool esParaEstaConversacion = false;
      if (emisorRut != null && receptorRut != null) {
        esParaEstaConversacion = (emisorRut == widget.rutAmigo && receptorRut == _rutUsuarioAutenticadoReal) ||
                                (emisorRut == _rutUsuarioAutenticadoReal && receptorRut == widget.rutAmigo);
      }
      
      if (!esParaEstaConversacion) {
        return;
      }
      
      setState(() {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            text: "Mensaje eliminado",
            isDeleted: true,
          );
        } else {
          _reloadMessages();
        }
      });
      
    } catch (e) {
      print('ERROR procesando mensaje eliminado: $e');
    }
  }

  Future<void> _reloadMessages() async {
    setState(() {
      _messages.clear();
    });
    await _fetchMessages();
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
              final message = Message(
                id: messageId,
                senderRut: messageData['emisor'].toString(),
                text: messageData['contenido'].toString(),
                timestamp: DateTime.parse(messageData['fecha']),
                isEdited: messageData['editado'] ?? false,
                isDeleted: messageData['eliminado'] ?? false,
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
                        '${json['emisor'] == _rutUsuarioAutenticadoReal ? "Tú" : widget.nombre} - ${DateTime.parse(json['fecha']).day}/${DateTime.parse(json['fecha']).month}/${DateTime.parse(json['fecha']).year}',
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

  // Función para editar mensaje
  Future<void> _editMessage(int messageId, String newContent) async {
    if (_jwtToken == null) return;

    try {
      final Uri requestUri = Uri.parse('${confGlobal.baseUrl}/chat/mensaje');
      
      final response = await http.put(
        requestUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_jwtToken',
        },
        body: json.encode({
          'idMensaje': messageId,
          'nuevoContenido': newContent,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensaje editado correctamente')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error editando mensaje: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('ERROR editando mensaje: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al editar mensaje: $e')),
      );
    }
  }

  // Función para eliminar mensaje
  Future<void> _deleteMessage(int messageId) async {
    if (_jwtToken == null) return;

    try {
      final Uri requestUri = Uri.parse('${confGlobal.baseUrl}/chat/mensaje/$messageId');
      
      final response = await http.delete(
        requestUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_jwtToken',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensaje eliminado correctamente')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error eliminando mensaje: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('ERROR eliminando mensaje: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar mensaje: $e')),
      );
    }
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
        backgroundColor: const Color(0xFF2E8B57),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                widget.nombre.isNotEmpty ? widget.nombre[0] : '?',
                style: const TextStyle(color: Color(0xFF2E8B57)),
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
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
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
                
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!isMe) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF2E8B57),
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
                              color: isMe ? const Color(0xFF2E8B57) : Colors.grey[300],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.isDeleted ? "Mensaje eliminado" : message.text,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                    fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: isMe ? Colors.white70 : Colors.black54,
                                        fontSize: 10,
                                      ),
                                    ),
                                    if (message.isEdited) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '(editado)',
                                        style: TextStyle(
                                          color: isMe ? Colors.white70 : Colors.black54,
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
                          backgroundColor: const Color(0xFF2E8B57),
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
                  backgroundColor: const Color(0xFF2E8B57),
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
}
