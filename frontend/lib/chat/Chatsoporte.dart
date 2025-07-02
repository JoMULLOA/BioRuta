import 'package:flutter/material.dart';

class ChatSoporte extends StatefulWidget {
  @override
  _ChatSoporteState createState() => _ChatSoporteState();
}

class _ChatSoporteState extends State<ChatSoporte> {
  final List<Map<String, dynamic>> chatMessages = [
    {"message": "Bienvenido al soporte. ¿En qué puedo ayudarte?", "isUserMessage": false},
  ];

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

  bool mostrarOpciones = true;
  final ScrollController _scrollController = ScrollController();

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

  void handleSupervisorRequest() {
    setState(() {
      chatMessages.add({"message": "Quiero hablar con un supervisor.", "isUserMessage": true});
      chatMessages.add({"message": "Un supervisor se pondrá en contacto contigo pronto.", "isUserMessage": false});
      mostrarOpciones = false;
    });
    _scrollToBottom();
  }

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
      body: Container(
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
              if (mostrarOpciones)
                Column(
                  children: [
                    for (int i = 0; i < options.length; i++)
                      _buildOptionButton(options[i], () => handleOptionSelection(i), principal: principal, secundario: secundario),
                    _buildSupervisorButton("Hablar con un supervisor", principal: principal, secundario: secundario),
                  ],
                ),
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
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: secundario,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: handleSupervisorRequest,
      child: Text(
        text,
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }
}
