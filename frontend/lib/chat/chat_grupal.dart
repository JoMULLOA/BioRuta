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

  ChatGrupalScreen({
    Key? key,
    required this.idViaje,
    this.nombreViaje,
  }) : super(key: key) {
    print('🚗🏗️ CONSTRUCTOR ChatGrupalScreen llamado para viaje: $idViaje');
  }

  @override
  ChatGrupalScreenState createState() {
    print('🚗🏭 CREATESTATE ChatGrupalScreen llamado para viaje: $idViaje');
    return ChatGrupalScreenState();
  }
}

class ChatGrupalScreenState extends State<ChatGrupalScreen> {
  ChatGrupalScreenState() {
    print('🚗🏭 CONSTRUCTOR ChatGrupalScreenState llamado');
  }
  
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
    print('🚗🔄 Inicializando chat grupal para viaje: ${widget.idViaje}');
    _initializarDatos();
  }

  Future<void> _initializarDatos() async {
    setState(() {
      isLoading = true;
    });

    try {
      print('🚗🔧 INICIANDO _initializarDatos para viaje: ${widget.idViaje}');
      
      // Obtener RUT del usuario actual (igual que chat 1 a 1)
      print('🚗👤 Obteniendo RUT del usuario...');
      userRut = await ChatGrupalService.obtenerRutUsuarioActual();
      print('🚗👤 RUT obtenido: $userRut');
      
      // Configurar listeners de socket
      print('🚗🎧 Configurando listeners de socket...');
      _setupSocketListeners();
      
      // Cargar mensajes históricos SIEMPRE (clave del patrón 1 a 1)
      print('🚗📚 A punto de llamar a _fetchMessages...');
      await _fetchMessages();
      print('🚗📚 _fetchMessages completado');
      
      // Unirse al chat grupal
      print('🚗🚪 Uniéndose al chat grupal...');
      ChatGrupalService.unirseAlChatGrupal(widget.idViaje);
      
      setState(() {
        isLoading = false;
      });
      
      print('✅ Chat grupal inicializado correctamente');
    } catch (e) {
      setState(() {
        errorMessage = 'Error al inicializar chat grupal: $e';
        isLoading = false;
      });
      print('❌ Error inicializando chat grupal: $e');
      print('❌ Stack trace: ${e.toString()}');
    }
  }

  // --- Método para cargar mensajes históricos (igual que chat 1 a 1) ---
  Future<void> _fetchMessages() async {
    try {
      print('🚗📥 Cargando mensajes históricos para viaje: ${widget.idViaje}');
      
      print('🚗🔄 Llamando a ChatGrupalService.obtenerMensajesGrupales...');
      final mensajesResult = await ChatGrupalService.obtenerMensajesGrupales(widget.idViaje);
      print('🚗📋 Mensajes obtenidos: ${mensajesResult.length}');
      
      print('🚗🔄 Llamando a ChatGrupalService.obtenerParticipantes...');
      final participantesResult = await ChatGrupalService.obtenerParticipantes(widget.idViaje);
      print('🚗👥 Participantes obtenidos: ${participantesResult.length}');
      
      setState(() {
        mensajes = mensajesResult;
        participantes = participantesResult;
      });
      
      print('🚗✅ Mensajes históricos cargados: ${mensajes.length} mensajes, ${participantes.length} participantes');
      
      // Hacer scroll al final
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('❌ Error cargando mensajes históricos: $e');
      print('❌ Stack trace completo: ${StackTrace.current}');
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
      print('🚗📶 Estado conexión cambiado: $connected');
      setState(() {
        isConnected = connected;
      });
    });
    
    // Verificar estado inicial de conexión
    Future.delayed(Duration.zero, () {
      final socketConnected = _socketService.socket?.connected ?? false;
      print('🚗📶 Estado inicial socket: $socketConnected');
      if (socketConnected && !isConnected) {
        print('🚗📶 Corrigiendo estado de conexión inicial');
        setState(() {
          isConnected = true;
        });
      }
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
    } else if (eventType == 'permission_error' && data['_needsReinitialization'] == true) {
      _handlePermissionError();
    }
  }

  // Manejar error de permisos e intentar re-inicialización
  void _handlePermissionError() async {
    print('🚗🔧 Manejando error de permisos, intentando re-inicializar chat...');
    
    try {
      // Mostrar mensaje al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔧 Inicializando chat grupal, intenta enviar el mensaje nuevamente...'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );
      
      // Intentar inicializar el chat grupal
      final success = await ChatGrupalService.inicializarChatGrupal(widget.idViaje);
      
      if (success) {
        print('🚗✅ Chat grupal re-inicializado exitosamente');
        
        // Volver a unirse al chat
        ChatGrupalService.unirseAlChatGrupal(widget.idViaje);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Chat grupal listo, puedes enviar mensajes ahora'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('🚗❌ Falló la re-inicialización del chat grupal');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se pudo inicializar el chat. Contacta al conductor.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('🚗❌ Error durante re-inicialización: $e');
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
    if (contenido.isNotEmpty) {
      print('🚗📤 Enviando mensaje: "$contenido"');
      print('🚗📶 Estado conexión: $isConnected');
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
    print('🚗🧹 Limpiando chat grupal y saliendo del viaje: ${widget.idViaje}');
    
    // Limpiar mensajes de memoria antes de salir
    setState(() {
      mensajes.clear();
      participantes.clear();
    });
    
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
                          _initializarDatos();
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
                              color: principal, // Siempre habilitado
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: _sendMessage, // Siempre habilitado
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
