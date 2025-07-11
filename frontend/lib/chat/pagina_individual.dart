import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
// import '../models/mensaje_model.dart'; // Temporalmente comentado
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
  final List<Message> _filteredMessages = []; // Para búsqueda
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();
  
  String? _jwtToken;
  String? _rutUsuarioAutenticadoReal;
  late SocketService _socketService;
  late StreamSubscription<Map<String, dynamic>> _messageSubscription;
  late StreamSubscription<bool> _connectionSubscription;
  late StreamSubscription<Map<String, dynamic>> _editedMessageSubscription;
  late StreamSubscription<Map<String, dynamic>> _deletedMessageSubscription;
  bool _isConnected = false;
  bool _isSearching = false;
  String _searchTerm = '';
  
  // Para edición de mensajes
  int? _editingMessageId;
  final TextEditingController _editController = TextEditingController();

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
    _editedMessageSubscription.cancel();
    _deletedMessageSubscription.cancel();
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
    print('🔍 DEBUG: Antes de llamar _fetchMessages');
    await _fetchMessages();
    print('🔍 DEBUG: Después de llamar _fetchMessages');

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
      
      // Inicializar estado de conexión con el valor actual
      setState(() {
        _isConnected = _socketService.isConnected;
      });
      
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
      
      // Escuchar mensajes editados
      _editedMessageSubscription = _socketService.editedMessageStream.listen((messageData) {
        print('📝 Stream de mensaje editado recibido en página: $messageData');
        _handleEditedMessage(messageData);
      });
      
      // Escuchar mensajes eliminados
      _deletedMessageSubscription = _socketService.deletedMessageStream.listen((messageData) {
        print('🗑️ Stream de mensaje eliminado recibido en página: $messageData');
        _handleDeletedMessage(messageData);
      });
      
    } catch (e) {
      print('ERROR conectando socket: $e');
    }
  }

  void _handleNewSocketMessage(Map<String, dynamic> messageData) {
    if (!mounted) return;
    
    try {
      print('📨 Procesando nuevo mensaje: $messageData');
      
      // Si es un mensaje editado o eliminado, no procesar aquí (se procesará en streams dedicados)
      if (messageData['_isEdited'] == true || messageData['_isDeleted'] == true) {
        print('� Mensaje editado/eliminado detectado, saltando procesamiento normal');
        return;
      }
      
      // Verificar que el mensaje es para esta conversación
      final emisorRut = messageData['emisor'];
      final receptorRut = messageData['receptor'];
      
      print('🔍 Verificando emisor: $emisorRut, receptor: $receptorRut');
      
      // Los RUTs vienen como strings directos del backend
      String emisorRutString = emisorRut.toString();
      String? receptorRutString = receptorRut?.toString();
      
      print('🔍 Emisor string: $emisorRutString, Receptor string: $receptorRutString');
      print('🔍 Widget rutAmigo: ${widget.rutAmigo}, Usuario autenticado: $_rutUsuarioAutenticadoReal');
      
      bool esParaEstaConversacion = false;
      
      if (receptorRutString != null) {
        // Es un mensaje 1 a 1
        esParaEstaConversacion = (emisorRutString == widget.rutAmigo && receptorRutString == _rutUsuarioAutenticadoReal) ||
                                (emisorRutString == _rutUsuarioAutenticadoReal && receptorRutString == widget.rutAmigo);
      }
      
      print('🔍 Es para esta conversación: $esParaEstaConversacion');
      
      if (esParaEstaConversacion) {
        print('✅ Creando mensaje para agregar a la conversación');
        
        // Crear mensaje usando el constructor directo con conversión correcta
        final nuevoMensaje = Message(
          id: messageData['id'] is String ? int.tryParse(messageData['id']) : messageData['id'],
          senderRut: messageData['emisor'].toString(),
          text: messageData['contenido'].toString(),
          timestamp: DateTime.parse(messageData['fecha']),
          isEdited: messageData['editado'] ?? false,
          isDeleted: messageData['eliminado'] ?? false,
        );
        
        print('✅ Mensaje creado: ID=${nuevoMensaje.id}, Sender=${nuevoMensaje.senderRut}, Text=${nuevoMensaje.text}');
        
        setState(() {
          // Evitar duplicados
          if (!_messages.any((m) => 
              m.id == nuevoMensaje.id ||
              (m.senderRut == nuevoMensaje.senderRut && 
               m.text == nuevoMensaje.text && 
               m.timestamp.difference(nuevoMensaje.timestamp).abs().inSeconds < 2))) {
            _messages.add(nuevoMensaje);
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            print('✅ Mensaje agregado. Total mensajes: ${_messages.length}');
          } else {
            print('⚠️ Mensaje duplicado, no agregado');
          }
        });
        
        _scrollToBottom();
        print('✅ Mensaje agregado a la conversación');
      } else {
        print('❌ Mensaje no es para esta conversación');
      }
    } catch (e) {
      print('ERROR procesando mensaje socket: $e');
      print('ERROR Stack trace: ${e.toString()}');
    }
  }

  void _handleEditedMessage(Map<String, dynamic> messageData) {
    if (!mounted) return;
    
    try {
      print('🔄 Procesando mensaje editado: $messageData');
      
      // Buscar ID del mensaje - puede venir como 'id' o 'idMensaje'
      final messageId = messageData['id'] is String ? int.tryParse(messageData['id']) : messageData['id'] ??
                        messageData['idMensaje'] is String ? int.tryParse(messageData['idMensaje']) : messageData['idMensaje'];
      final newContent = messageData['contenido'] ?? messageData['nuevoContenido'];
      
      print('🔄 ID del mensaje editado: $messageId, Nuevo contenido: $newContent');
      
      if (messageId == null) {
        print('❌ No se encontró ID del mensaje editado');
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
      
      print('🔄 Es para esta conversación: $esParaEstaConversacion');
      
      if (!esParaEstaConversacion) {
        print('❌ Mensaje editado no pertenece a esta conversación');
        return;
      }        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              text: newContent,
              isEdited: true,
            );
            print('✅ Mensaje editado actualizado en la posición $index');
            print('✅ Nuevo texto: ${_messages[index].text}');
          } else {
            print('❌ No se encontró mensaje con ID $messageId para editar');
            print('❌ Mensajes disponibles: ${_messages.map((m) => 'ID: ${m.id}').toList()}');
            // Si no se encuentra el mensaje, recargar como respaldo
            print('🔄 Recargando mensajes como respaldo...');
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
      print('🗑️ Procesando mensaje eliminado: $messageData');
      
      // Buscar ID del mensaje - puede venir como 'id' o 'idMensaje'
      final messageId = messageData['id'] is String ? int.tryParse(messageData['id']) : messageData['id'] ??
                        messageData['idMensaje'] is String ? int.tryParse(messageData['idMensaje']) : messageData['idMensaje'];
      
      print('🗑️ ID del mensaje eliminado: $messageId');
      
      if (messageId == null) {
        print('❌ No se encontró ID del mensaje eliminado');
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
      
      print('🗑️ Es para esta conversación: $esParaEstaConversacion');
      
      if (!esParaEstaConversacion) {
        print('❌ Mensaje eliminado no pertenece a esta conversación');
        return;
      }        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              isDeleted: true,
            );
            print('✅ Mensaje eliminado actualizado en la posición $index');
          } else {
            print('❌ No se encontró mensaje con ID $messageId para eliminar');
            print('❌ Mensajes disponibles: ${_messages.map((m) => 'ID: ${m.id}').toList()}');
            // Si no se encuentra el mensaje, recargar como respaldo
            print('🔄 Recargando mensajes como respaldo...');
            _reloadMessages();
          }
        });
      
    } catch (e) {
      print('ERROR procesando mensaje eliminado: $e');
    }
  }

  // Método para recargar mensajes (usado como respaldo)
  Future<void> _reloadMessages() async {
    print('🔄 Recargando mensajes...');
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
      print('🔍 DEBUG: Preparando URI...');
      print('🔍 DEBUG: baseUrl: ${confGlobal.baseUrl}');
      print('🔍 DEBUG: rutAmigo: ${widget.rutAmigo}');
      print('🔍 DEBUG: rutAmigo type: ${widget.rutAmigo.runtimeType}');
      
      print('🔍 DEBUG: Intentando crear URI...');
      final Uri requestUri = Uri.parse('${confGlobal.baseUrl}/chat/conversacion/${widget.rutAmigo}');
      print('🔍 DEBUG: URI creada exitosamente: $requestUri');
      
      print('DEBUG: Intentando GET historial de mensajes de: $requestUri');

      print('🔍 DEBUG: Iniciando request HTTP...');
      final response = await http.get(
        requestUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_jwtToken',
        },
      );
      print('🔍 DEBUG: Request HTTP completado exitosamente');

      print('DEBUG: Código de estado del historial: ${response.statusCode}');
      print('DEBUG: Cuerpo de la respuesta del historial: ${response.body}');

      print('🔍 DEBUG: Verificando código de estado...');
      print('🔍 DEBUG: response.statusCode = ${response.statusCode}');
      print('🔍 DEBUG: response.statusCode == 200 = ${response.statusCode == 200}');

      if (response.statusCode == 200) {
        print('🔍 DEBUG: Entrando al bloque if (response.statusCode == 200)');
        try {
          print('🧪 PRUEBA: Respuesta recibida correctamente');
          print('🧪 PRUEBA: Response body length: ${response.body.length}');
          
          // Agregar debugging específico antes del json.decode
          print('🔍 DEBUG: Intentando parsear JSON...');
          print('🔍 DEBUG: Response body type: ${response.body.runtimeType}');
          print('🔍 DEBUG: Response body: ${response.body}');
          
          List<dynamic> responseData;
          try {
            responseData = json.decode(response.body);
            print('🔍 DEBUG: JSON parseado correctamente');
            print('🔍 DEBUG: Response data type: ${responseData.runtimeType}');
            print('🔍 DEBUG: Response data length: ${responseData.length}');
          } catch (jsonError) {
            print('❌ ERROR en json.decode: $jsonError');
            print('❌ ERROR tipo: ${jsonError.runtimeType}');
            throw jsonError;
          }
          
          final List<dynamic> messagesJson = responseData;

          print('📥 Procesando ${messagesJson.length} mensajes del historial...');

          List<Message> newMessages = [];
          
          for (int i = 0; i < messagesJson.length; i++) {
            try {
              print('🔍 DEBUG: Procesando mensaje en índice $i');
              print('🔍 DEBUG: Tipo de índice i: ${i.runtimeType}');
              print('🔍 DEBUG: Valor de i: $i');
              print('🔍 DEBUG: Accediendo a messagesJson[$i]...');
              
              final messageData = messagesJson[i];
              print('🔍 DEBUG: Mensaje obtenido exitosamente');
              print('📥 Procesando mensaje $i: ID=${messageData['id']}, Emisor=${messageData['emisor']}, Contenido=${messageData['contenido']}');
              
              // Crear mensaje directamente en lugar del factory temporalmente
              print('🔍 DEBUG: Creando mensaje directamente...');
              print('🔍 DEBUG: messageData[id]: ${messageData['id']}');
              print('🔍 DEBUG: messageData[emisor]: ${messageData['emisor']}');
              print('🔍 DEBUG: messageData[contenido]: ${messageData['contenido']}');
              print('🔍 DEBUG: messageData[fecha]: ${messageData['fecha']}');
              print('🔍 DEBUG: messageData[editado]: ${messageData['editado']}');
              print('🔍 DEBUG: messageData[eliminado]: ${messageData['eliminado']}');
              
              // Convertir id
              int? messageId = messageData['id'] is String ? int.tryParse(messageData['id']) : messageData['id'];
              print('🔍 DEBUG: messageId convertido: $messageId');
              
              // Crear mensaje paso a paso
              print('🔍 DEBUG: Creando DateTime...');
              DateTime timestamp = DateTime.parse(messageData['fecha']);
              print('🔍 DEBUG: DateTime creado: $timestamp');
              
              print('🔍 DEBUG: Llamando al constructor Message...');
              final message = Message(
                id: messageId,
                senderRut: messageData['emisor'].toString(),
                text: messageData['contenido'].toString(),
                timestamp: timestamp,
                isEdited: messageData['editado'] ?? false,
                isDeleted: messageData['eliminado'] ?? false,
              );
              print('🔍 DEBUG: Mensaje creado exitosamente');
              
              newMessages.add(message);
              print('✅ Mensaje $i procesado correctamente');
            } catch (e) {
              print('❌ Error procesando mensaje $i: $e');
              print('❌ Error tipo: ${e.runtimeType}');
              print('❌ Datos del mensaje: ${messagesJson[i]}');
            }
          }

          setState(() {
            _messages.clear();
            _messages.addAll(newMessages);
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            print('✅ Historial cargado. Total mensajes: ${_messages.length}');
          });

          _scrollToBottom();
          
          print('🧪 PRUEBA: Método _fetchMessages completado con procesamiento');
        } catch (e) {
          print('❌ Error procesando respuesta del historial: $e');
          print('❌ Error stack trace: ${e.toString()}');
          print('❌ Response body: ${response.body}');
          
          // Agregar información específica del error
          if (e is TypeError) {
            print('❌ TypeError específico: ${e.toString()}');
          }
          if (e is FormatException) {
            print('❌ FormatException específico: ${e.toString()}');
          }
        }
      } else {
        print('ERROR al obtener historial: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('ERROR de conexión al obtener historial: $e');
      print('ERROR Stack trace: ${e.toString()}');
      print('ERROR tipo de error: ${e.runtimeType}');
      if (e is TypeError) {
        print('ERROR TypeError details: ${e.toString()}');
      }
      if (e is FormatException) {
        print('ERROR FormatException details: ${e.toString()}');
      }
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
        final List<dynamic> responseData = json.decode(response.body);
        
        // Mostrar los resultados en un diálogo
        _showSearchResults(responseData, query);
      } else {
        print('ERROR al buscar mensajes: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('ERROR de conexión al buscar mensajes: $e');
    }
  }

  // Mostrar diálogo de búsqueda
  void _showSearchDialog() {
    String searchQuery = '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar mensajes'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Escribe tu búsqueda...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            searchQuery = value;
          },
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context);
              _searchMessages(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (searchQuery.trim().isNotEmpty) {
                Navigator.pop(context);
                _searchMessages(searchQuery.trim());
              }
            },
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  // Mostrar resultados de búsqueda
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
        // También enviar por WebSocket para actualizaciones en tiempo real
        _socketService.editMessage(
          idMensaje: messageId,
          nuevoContenido: newContent,
        );
        
        print('✅ Mensaje editado exitosamente');
        
        // Recargar mensajes después de un pequeño delay para asegurar que se actualizó
        await Future.delayed(Duration(milliseconds: 500));
        await _reloadMessages();
      } else {
        print('ERROR al editar mensaje: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al editar mensaje')),
        );
      }
    } catch (e) {
      print('ERROR de conexión al editar mensaje: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
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
        // También enviar por WebSocket para actualizaciones en tiempo real
        _socketService.deleteMessage(idMensaje: messageId);
        
        print('✅ Mensaje eliminado exitosamente');
        
        // Recargar mensajes después de un pequeño delay para asegurar que se actualizó
        await Future.delayed(Duration(milliseconds: 500));
        await _reloadMessages();
      } else {
        print('ERROR al eliminar mensaje: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar mensaje')),
        );
      }
    } catch (e) {
      print('ERROR de conexión al eliminar mensaje: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    }
  }

  // Mostrar opciones de mensaje (editar/eliminar)
  void _showMessageOptions(Message message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar mensaje'),
              onTap: () {
                Navigator.pop(context);
                _startEditingMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar mensaje', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Iniciar edición de mensaje
  void _startEditingMessage(Message message) {
    setState(() {
      _editingMessageId = message.id;
      _editController.text = message.text;
    });
  }

  // Confirmar eliminación de mensaje
  void _confirmDeleteMessage(Message message) {
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
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Cancelar edición
  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _editController.clear();
    });
  }

  // Confirmar edición
  void _confirmEdit() {
    if (_editingMessageId != null && _editController.text.trim().isNotEmpty) {
      _editMessage(_editingMessageId!, _editController.text.trim());
      _cancelEditing();
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
            child: GestureDetector(
              onLongPress: () {
                // Solo mostrar opciones para mensajes propios y no eliminados
                if (isMe && !message.isDeleted && message.id != null) {
                  _showMessageOptions(message);
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: message.isDeleted 
                      ? Colors.grey[300] 
                      : (isMe ? Colors.blue : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.isDeleted ? 'Mensaje eliminado' : message.text,
                      style: TextStyle(
                        color: message.isDeleted 
                            ? Colors.grey[600]
                            : (isMe ? Colors.white : Colors.black87),
                        fontSize: 16,
                        fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: message.isDeleted 
                                ? Colors.grey[500]
                                : (isMe ? Colors.white70 : Colors.grey[600]),
                            fontSize: 12,
                          ),
                        ),
                        if (message.isEdited && !message.isDeleted) ...[
                          SizedBox(width: 4),
                          Text(
                            '• editado',
                            style: TextStyle(
                              color: isMe ? Colors.white60 : Colors.grey[500],
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
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(
                  MediaQuery.of(context).size.width - 100,
                  kToolbarHeight,
                  0,
                  0,
                ),
                items: [
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.search),
                        SizedBox(width: 8),
                        Text('Buscar mensajes'),
                      ],
                    ),
                    onTap: () {
                      // Usar Future.delayed para evitar problemas con el context
                      Future.delayed(Duration.zero, () {
                        _showSearchDialog();
                      });
                    },
                  ),
                ],
              );
            },
          ),
        ],
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
            child: Column(
              children: [
                // Mostrar banner de edición si está editando
                if (_editingMessageId != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Editando mensaje',
                            style: TextStyle(color: Colors.blue[700]),
                          ),
                        ),
                        IconButton(
                          onPressed: _cancelEditing,
                          icon: Icon(Icons.close, color: Colors.blue),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                
                // Campo de entrada
                SizedBox(height: _editingMessageId != null ? 8 : 0),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _editingMessageId != null ? _editController : _messageController,
                        decoration: InputDecoration(
                          hintText: _editingMessageId != null ? 'Editar mensaje...' : 'Escribe un mensaje...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onSubmitted: (_) {
                          if (_editingMessageId != null) {
                            _confirmEdit();
                          } else {
                            _sendMessage();
                          }
                        },
                        maxLines: null,
                      ),
                    ),
                    SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: () {
                        if (_editingMessageId != null) {
                          _confirmEdit();
                        } else {
                          _sendMessage();
                        }
                      },
                      child: Icon(_editingMessageId != null ? Icons.check : Icons.send),
                      mini: true,
                      backgroundColor: _isConnected ? Colors.blue : Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
