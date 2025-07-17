import 'package:flutter/material.dart';
import 'dart:async';
import '../models/chat_grupal_models.dart';
import '../services/chat_grupal_service.dart';
import '../services/socket_service.dart';
import '../widgets/mensaje_grupal_widget.dart';
import '../widgets/participantes_header_widget.dart';

class ChatGrupalScreen extends StatefulWidget {
  final String idViaje;
  final String? nombreViaje;

  const ChatGrupalScreen({
    Key? key,
    required this.idViaje,
    this.nombreViaje,
  }) : super(key: key);

  @override
  ChatGrupalScreenState createState() => ChatGrupalScreenState();
}

class ChatGrupalScreenState extends State<ChatGrupalScreen> {
  // --- Variables de Estado ---
  List<MensajeGrupal> mensajes = [];
  List<ParticipanteChat> participantes = [];
  bool isLoading = true;
  bool isConnected = false;
  String? errorMessage;
  String? userRut;
  
  // --- Controladores ---
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  // --- Servicios ---
  final SocketService _socketService = SocketService.instance;
  
  // --- Subscripciones ---
  StreamSubscription? _messageSubscription;
  StreamSubscription? _participantsSubscription;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _connectionSubscription;
  
  // --- Colores del tema ---
  final Color fondo = const Color(0xFFF8F2EF);
  final Color principal = const Color(0xFF6B3B2D);
  final Color secundario = const Color(0xFF8D4F3A);
  final Color fondoMensaje = const Color(0xFFF5F5F5);
  
  @override
  void initState() {
    super.initState();
    _initializeChatGrupal();
  }

  Future<void> _initializeChatGrupal() async {
    try {
      // Obtener RUT del usuario actual
      userRut = await ChatGrupalService.obtenerRutUsuarioActual();
      
      // Configurar listeners de socket
      _setupSocketListeners();
      
      // Cargar datos iniciales
      await _loadInitialData();
      
      // Unirse al chat grupal
      ChatGrupalService.unirseAlChatGrupal(widget.idViaje);
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error al inicializar chat grupal: $e';
        isLoading = false;
      });
      print('❌ Error inicializando chat grupal: $e');
    }
  }

  Future<void> _loadInitialData() async {
    try {
      // Cargar mensajes y participantes en paralelo
      final futures = await Future.wait([
        ChatGrupalService.obtenerMensajesGrupales(widget.idViaje),
        ChatGrupalService.obtenerParticipantes(widget.idViaje),
      ]);
      
      setState(() {
        mensajes = futures[0] as List<MensajeGrupal>;
        participantes = futures[1] as List<ParticipanteChat>;
      });
      
      // Hacer scroll al final
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('❌ Error cargando datos iniciales: $e');
    }
  }

  void _setupSocketListeners() {
    // Listener para mensajes grupales
    _messageSubscription = _socketService.groupMessageStream.listen((data) {
      print('🚗💬 Nuevo mensaje grupal recibido en UI: $data');
      final mensaje = MensajeGrupal.fromJson(data);
      setState(() {
        mensajes.add(mensaje);
      });
      _scrollToBottom();
    });

    // Listener para cambios en participantes
    _participantsSubscription = _socketService.groupParticipantsStream.listen((data) {
      print('🚗👥 Cambio en participantes: $data');
      _handleParticipantChange(data);
    });

    // Listener para eventos del chat grupal
    _eventsSubscription = _socketService.groupChatEventsStream.listen((data) {
      print('🚗📊 Evento del chat grupal: $data');
      _handleChatEvent(data);
    });

    // Listener para estado de conexión
    _connectionSubscription = _socketService.connectionStream.listen((connected) {
      setState(() {
        isConnected = connected;
      });
    });

    // Listener para mensajes editados
    _socketService.editedMessageStream.listen((data) {
      if (data['tipo'] == 'grupal' && data['idViajeMongo'] == widget.idViaje) {
        _handleMessageEdited(data);
      }
    });

    // Listener para mensajes eliminados
    _socketService.deletedMessageStream.listen((data) {
      if (data['tipo'] == 'grupal') {
        _handleMessageDeleted(data);
      }
    });
  }

  void _handleParticipantChange(Map<String, dynamic> data) {
    final eventType = data['_eventType'];
    
    if (eventType == 'participant_joined') {
      final nuevoParticipante = data['nuevoParticipante'];
      _showParticipantNotification('$nuevoParticipante se unió al chat', Icons.person_add, Colors.green);
    } else if (eventType == 'participant_left') {
      final participanteSalio = data['participanteSalio'];
      _showParticipantNotification('$participanteSalio salió del chat', Icons.person_remove, Colors.orange);
    }
    
    // Actualizar lista de participantes
    if (data['participantes'] != null) {
      setState(() {
        participantes = (data['participantes'] as List<dynamic>)
            .map((p) => ParticipanteChat.fromJson(p))
            .toList();
      });
    }
  }

  void _handleChatEvent(Map<String, dynamic> data) {
    final eventType = data['_eventType'];
    
    if (eventType == 'group_chat_finished') {
      _showChatFinishedDialog();
    } else if (eventType == 'removed_from_group_chat') {
      _showRemovedFromChatDialog();
    }
  }

  void _handleMessageEdited(Map<String, dynamic> data) {
    final mensajeId = data['id'];
    
    setState(() {
      final index = mensajes.indexWhere((m) => m.id == mensajeId);
      if (index != -1) {
        mensajes[index] = MensajeGrupal.fromJson(data);
      }
    });
  }

  void _handleMessageDeleted(Map<String, dynamic> data) {
    final mensajeId = data['idMensaje'];
    
    setState(() {
      mensajes.removeWhere((m) => m.id == mensajeId);
    });
  }

  void _showParticipantNotification(String mensaje, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(mensaje),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.grey[800],
      ),
    );
  }

  void _showChatFinishedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Chat Finalizado'),
        content: const Text('El viaje ha finalizado y el chat grupal se ha cerrado.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Salir del chat
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showRemovedFromChatDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Eliminado del Chat'),
        content: const Text('Has sido eliminado del chat grupal del viaje.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Salir del chat
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
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

  void _sendMessage() {
    final contenido = _messageController.text.trim();
    if (contenido.isNotEmpty && isConnected) {
      ChatGrupalService.enviarMensajeGrupal(widget.idViaje, contenido);
      _messageController.clear();
      _focusNode.requestFocus();
    }
  }

  void _editMessage(MensajeGrupal mensaje, String nuevoContenido) {
    ChatGrupalService.editarMensajeGrupal(
      widget.idViaje,
      mensaje.id,
      nuevoContenido,
    );
  }

  void _deleteMessage(MensajeGrupal mensaje) {
    ChatGrupalService.eliminarMensajeGrupal(widget.idViaje, mensaje.id);
  }

  @override
  void dispose() {
    // Salir del chat grupal
    ChatGrupalService.salirDelChatGrupal(widget.idViaje);
    
    // Cancelar subscripciones
    _messageSubscription?.cancel();
    _participantsSubscription?.cancel();
    _eventsSubscription?.cancel();
    _connectionSubscription?.cancel();
    
    // Limpiar controladores
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: principal,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nombreViaje ?? 'Chat de Viaje',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${participantes.length} participantes',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Indicador de conexión
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: isConnected ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: principal),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            errorMessage = null;
                            isLoading = true;
                          });
                          _initializeChatGrupal();
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header con participantes
                    ParticipantesHeaderWidget(
                      participantes: participantes,
                      userRut: userRut,
                    ),
                    
                    // Lista de mensajes
                    Expanded(
                      child: mensajes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No hay mensajes aún',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sé el primero en escribir algo',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: mensajes.length,
                              itemBuilder: (context, index) {
                                return MensajeGrupalWidget(
                                  mensaje: mensajes[index],
                                  isOwn: mensajes[index].emisorRut == userRut,
                                  onEdit: _editMessage,
                                  onDelete: _deleteMessage,
                                );
                              },
                            ),
                    ),
                    
                    // Área de escritura
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: fondoMensaje,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _messageController,
                                focusNode: _focusNode,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Escribe un mensaje...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: isConnected ? principal : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: isConnected ? _sendMessage : null,
                              icon: const Icon(
                                Icons.send,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
