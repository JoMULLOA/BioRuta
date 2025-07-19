import 'package:flutter/material.dart';
import '../services/peticion_supervision_service.dart';
import '../services/socket_service.dart';
import '../chat/pagina_individual.dart';
import 'dart:async';

class ChatSoporte extends StatefulWidget {
  @override
  _ChatSoporteState createState() => _ChatSoporteState();
}

class _ChatSoporteState extends State<ChatSoporte> {
  List<Map<String, dynamic>> chatMessages = [];
  bool mostrarOpciones = true;
  bool _isCreatingRequest = false;
  bool _hasActivePetition = false;
  bool _hasPendingPetition = false;
  bool _isLoading = true; // Nueva variable para controlar el estado de carga
  Map<String, dynamic>? _peticionActiva;
  
  // Para escuchar notificaciones de peticiones
  final SocketService _socketService = SocketService.instance;
  StreamSubscription? _peticionesSubscription;

  @override
  void initState() {
    super.initState();
    
    // Verificar petición pendiente/activa al inicializar
    _verificarEstadoPeticiones();
    
    // Configurar listener para notificaciones de peticiones
    _setupPeticionesListener();
  }

  Future<void> _verificarEstadoPeticiones() async {
    try {
      // Primero verificar si tiene una petición pendiente
      final resultadoPendiente = await PeticionSupervisionService.verificarPeticionPendiente();
      
      if (resultadoPendiente['success'] && resultadoPendiente['tienePendiente']) {
        // Si tiene una petición pendiente, redirigir inmediatamente al perfil
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pop(); // Salir del chat de soporte
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tienes una petición de supervisión pendiente. Revisa tu perfil para ver el estado.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        });
        return;
      }

      // Si no tiene petición pendiente, verificar si tiene una activa
      final resultadoActiva = await PeticionSupervisionService.verificarPeticionActiva();
      
      setState(() {
        _isLoading = false;
        
        if (resultadoActiva['success'] && resultadoActiva['tieneActiva']) {
          _hasActivePetition = true;
          _peticionActiva = resultadoActiva['data'];
          
          // Mostrar mensaje de bienvenida con estado de petición activa
          chatMessages.add({
            "message": "¡Bienvenido de vuelta! Tienes una petición de supervisión activa.",
            "isUserMessage": false
          });
          
          if (_peticionActiva?['rutAdministrador'] != null) {
            final nombreAdmin = _peticionActiva?['administrador']?['nombreCompleto'] ?? 'el administrador';
            chatMessages.add({
              "message": "Ya tienes un chat abierto con $nombreAdmin. ¿Deseas continuar la conversación?",
              "isUserMessage": false
            });
          }
        } else {
          // Mensaje de bienvenida normal
          chatMessages.add({
            "message": "Bienvenido al soporte. ¿En qué puedo ayudarte?",
            "isUserMessage": false
          });
        }
      });
    } catch (e) {
      print('Error verificando peticiones: $e');
      setState(() {
        _isLoading = false;
        // Mensaje de bienvenida por defecto
        chatMessages.add({
          "message": "Bienvenido al soporte. ¿En qué puedo ayudarte?",
          "isUserMessage": false
        });
      });
    }
  }

  @override
  void dispose() {
    _peticionesSubscription?.cancel();
    super.dispose();
  }

  void _setupPeticionesListener() {
    // Escuchar eventos de peticiones de supervisión a través del stream de chat grupal
    _peticionesSubscription = _socketService.groupChatEventsStream.listen((data) {
      final eventType = data['_eventType'];
      
      if (eventType == 'peticion_aceptada_abrir_chat') {
        _manejarPeticionAceptada(data);
      } else if (eventType == 'peticion_respondida') {
        _manejarPeticionRespondida(data);
      } else if (eventType == 'peticion_solucionada') {
        _manejarPeticionSolucionada(data);
      }
    });
  }

  void _manejarPeticionAceptada(Map<String, dynamic> data) async {
    final rutAdministrador = data['_rutAdministrador'];
    final nombreAdministrador = data['_nombreAdministrador'];
    final respuesta = data['respuesta'];
    
    if (rutAdministrador != null && nombreAdministrador != null) {
      // Agregar mensaje sobre la aceptación
      setState(() {
        chatMessages.add({
          "message": "✅ ¡Excelente! Tu petición ha sido aceptada.\n\n${respuesta != null && respuesta.isNotEmpty ? 'Respuesta del administrador: $respuesta\n\n' : ''}Se abrirá el chat con $nombreAdministrador para continuar la conversación.",
          "isUserMessage": false
        });
      });
      
      // Mostrar notificación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Abriendo chat con $nombreAdministrador...'),
          backgroundColor: Color(0xFF6B3B2D),
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Esperar un momento antes de abrir el chat
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Abrir el chat con el administrador
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaginaIndividualWebSocket(
            nombre: nombreAdministrador,
            rutAmigo: rutAdministrador,
            rutUsuarioAutenticado: null, // Se obtendrá automáticamente del storage
          ),
        ),
      );
    }
  }

  void _manejarPeticionRespondida(Map<String, dynamic> data) {
    final estado = data['estado'];
    final respuesta = data['respuesta'];
    final administrador = data['administrador'];
    
    String mensaje;
    if (estado == 'denegada') {
      mensaje = "❌ Tu petición de supervisión ha sido denegada.";
      if (respuesta != null && respuesta.isNotEmpty) {
        mensaje += "\n\nMotivo: $respuesta";
      }
      if (administrador != null) {
        mensaje += "\n\nRevisado por: $administrador";
      }
      mensaje += "\n\n¿Hay algo más en lo que pueda ayudarte?";
      
      // Restablecer el estado para permitir nuevas interacciones
      setState(() {
        _hasPendingPetition = false;
        mostrarOpciones = true;
        chatMessages.add({
          "message": mensaje,
          "isUserMessage": false
        });
      });
    } else {
      mensaje = "ℹ️ Tu petición ha sido procesada.";
      if (respuesta != null && respuesta.isNotEmpty) {
        mensaje += "\n\nRespuesta: $respuesta";
      }
      
      setState(() {
        chatMessages.add({
          "message": mensaje,
          "isUserMessage": false
        });
      });
    }
  }

  void _manejarPeticionSolucionada(Map<String, dynamic> data) {
    setState(() {
      // Reiniciar el estado del chat
      _hasActivePetition = false;
      _peticionActiva = null;
      
      // Limpiar mensajes y mostrar mensaje de bienvenida normal
      chatMessages.clear();
      chatMessages.add({
        "message": "✅ Tu petición de supervisión ha sido marcada como solucionada.\n\nGracias por usar nuestro servicio de soporte. Si necesitas ayuda nuevamente, puedes crear una nueva petición.",
        "isUserMessage": false
      });
      chatMessages.add({
        "message": "Bienvenido al soporte. ¿En qué puedo ayudarte?",
        "isUserMessage": false
      });
      
      // Mostrar opciones nuevamente
      mostrarOpciones = true;
    });
    
    // Mostrar notificación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tu petición de supervisión ha sido solucionada'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  final List<String> options = [
    "1. ¿Tienes problemas de conexión?",
    "2. ¿No puedes iniciar sesión?",
    "3. ¿Otro problema?",
    "4. ¿Problemas con notificaciones?",
    "5. ¿No puedes actualizar la app?",
    "6. ¿Error al realizar un pago?",
    "7. ¿App se cierra inesperadamente?",
  ];

  final List<String> steps = [
    "Para problemas de conexión: Verifica tu conexión a internet y reinicia la aplicación.",
    "Para problemas de inicio de sesión: Asegúrate de que tu usuario y contraseña sean correctos.",
    "Para otros problemas: Intenta reiniciar tu dispositivo o actualizar la aplicación.",
    "Para notificaciones: Asegúrate de que la app tenga permisos de notificación habilitados en tu configuración.",
    "Si no puedes actualizar la app: Verifica que tengas suficiente espacio y acceso a internet. Luego intenta desde la tienda de aplicaciones.",
    "Para errores al pagar: Verifica que tu método de pago esté habilitado, y que tengas saldo disponible. Si el problema persiste, intenta con otro método.",
    "Si la app se cierra sola: Borra la caché de la aplicación o reinstálala desde la tienda.",
  ];

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

  void handleOptionSelection(int index) {
    setState(() {
      chatMessages.add({"message": options[index], "isUserMessage": true});
      chatMessages.add({"message": steps[index], "isUserMessage": false});
      chatMessages.add({"message": "¿Hay algo más en lo que pueda ayudarte?", "isUserMessage": false});
      mostrarOpciones = true;
    });
    _scrollToBottom();
  }

  void handleSupervisorRequest() async {
    setState(() {
      chatMessages.add({"message": "Quiero hablar con un supervisor.", "isUserMessage": true});
      chatMessages.add({"message": "Procesando tu solicitud de supervisión...", "isUserMessage": false});
      mostrarOpciones = false;
      _isCreatingRequest = true;
    });
    _scrollToBottom();

    try {
      // Crear la petición de supervisión automáticamente
      final resultado = await PeticionSupervisionService.crearPeticionSupervision(
        motivo: "Solicitud de chat de soporte",
        mensaje: "El usuario ha solicitado hablar con un supervisor desde el chat de soporte automático.",
        prioridad: "media",
      );

      setState(() {
        _isCreatingRequest = false;
        if (resultado['success']) {
          _hasPendingPetition = true; // Marcar que tiene petición pendiente
          chatMessages.removeLast(); // Remover mensaje de "procesando"
          chatMessages.add({
            "message": "✅ Tu solicitud ha sido enviada exitosamente.\n\nUn administrador revisará tu petición y te contactará pronto.\n\n⏳ Por favor espera mientras un administrador acepta tu petición...",
            "isUserMessage": false
          });
          // NO mostrar opciones - el usuario queda en espera
          mostrarOpciones = false;
        } else {
          // Verificar si el error es por petición existente
          if (resultado['message'].contains('petición de supervisión pendiente') || 
              resultado['message'].contains('chat activo')) {
            _hasPendingPetition = true;
            chatMessages.removeLast(); // Remover mensaje de "procesando"
            chatMessages.add({
              "message": "⏳ ${resultado['message']}\n\nPor favor espera mientras un administrador acepta tu petición...",
              "isUserMessage": false
            });
            // NO mostrar opciones - el usuario queda en espera
            mostrarOpciones = false;
          } else {
            chatMessages.removeLast(); // Remover mensaje de "procesando"
            chatMessages.add({
              "message": "❌ Hubo un error al enviar tu solicitud: ${resultado['message']}\n\nPor favor, intenta nuevamente más tarde.",
              "isUserMessage": false
            });
            // Volver a mostrar opciones solo si es un error diferente
            mostrarOpciones = true;
          }
        }
      });
    } catch (e) {
      setState(() {
        _isCreatingRequest = false;
        chatMessages.removeLast(); // Remover mensaje de "procesando"
        chatMessages.add({
          "message": "❌ Error de conexión al enviar la solicitud.\n\nVerifica tu conexión a internet e intenta nuevamente.",
          "isUserMessage": false
        });
        // Volver a mostrar opciones si hay error de conexión
        mostrarOpciones = true;
      });
    }

    _scrollToBottom();
  }

  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final Color fondo = Color(0xFFF8F2EF);
    final Color principal = Color(0xFF6B3B2D);
    final Color secundario = Color(0xFF8D4F3A);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: fondo,
        elevation: 0,
        title: Text('Soporte', style: TextStyle(color: principal)),
        iconTheme: IconThemeData(color: principal),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(principal),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Verificando estado de peticiones...',
                    style: TextStyle(
                      color: secundario,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : Container(
              color: fondo,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: chatMessages.length,
                        itemBuilder: (context, index) {
                          final chat = chatMessages[index];
                          return _buildMessageBubble(
                            chat["message"],
                            isUserMessage: chat["isUserMessage"],
                            principal: principal,
                            secundario: secundario,
                          );
                        },
                      ),
                    ),
                    if (mostrarOpciones && !_isCreatingRequest && !_hasPendingPetition)
                      Column(
                        children: [
                          for (int i = 0; i < options.length; i++)
                            _buildOptionButton(options[i], () => handleOptionSelection(i), principal: principal, secundario: secundario),
                          _buildSupervisorButton("Hablar con un supervisor", principal: principal, secundario: secundario),
                        ],
                      ),
                    if (_isCreatingRequest)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(principal),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Enviando solicitud de supervisión...',
                              style: TextStyle(
                                color: secundario,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_hasPendingPetition && !_isCreatingRequest)
                      _buildWaitingWidget(principal, secundario),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMessageBubble(String message, {required bool isUserMessage, required Color principal, required Color secundario}) {
    return Align(
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        margin: EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: isUserMessage ? principal : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isUserMessage ? Colors.white : secundario,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(String option, VoidCallback onPressed, {required Color principal, required Color secundario}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: principal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          option,
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSupervisorButton(String text, {required Color principal, required Color secundario}) {
    // Si hay petición activa, mostrar botón para reanudar chat
    if (_hasActivePetition && _peticionActiva?['rutAdministrador'] != null) {
      return Column(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _reanudarChatConAdministrador(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Reanudar chat con ${_peticionActiva?['administrador']?['nombreCompleto'] ?? 'administrador'}',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ya tienes un chat activo con un administrador',
            style: TextStyle(
              fontSize: 12,
              color: secundario,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    
    // Botón normal para solicitar supervisor
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: secundario,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: _isCreatingRequest ? null : handleSupervisorRequest,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.support_agent, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _reanudarChatConAdministrador() {
    final rutAdministrador = _peticionActiva?['rutAdministrador'];
    final nombreAdministrador = _peticionActiva?['administrador']?['nombreCompleto'] ?? 'Administrador';
    
    if (rutAdministrador != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaginaIndividualWebSocket(
            nombre: nombreAdministrador,
            rutAmigo: rutAdministrador,
            rutUsuarioAutenticado: null, // Se obtendrá automáticamente del storage
          ),
        ),
      );
    }
  }

  Widget _buildWaitingWidget(Color principal, Color secundario) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(principal),
          ),
          SizedBox(height: 8),
          Text(
            'Esperando respuesta de un administrador...',
            style: TextStyle(
              color: secundario,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Por favor, no cierres la aplicación. Te notificaremos cuando un administrador esté disponible.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
