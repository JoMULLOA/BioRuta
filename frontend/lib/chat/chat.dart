import 'package:flutter/material.dart';
import 'package:BioRuta/navbar_widget.dart';  // Importa tu navbar
import 'package:BioRuta/services/socket_service.dart';  // Asegúrate de importar el SocketService

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final SocketService _socketService = SocketService();
  final TextEditingController _messageController = TextEditingController();
  List<String> messages = [];  // Lista de mensajes para mostrar

  @override
  void initState() {
    super.initState();
    _socketService.connect();  // Conectar al WebSocket al iniciar

    // Escuchar los mensajes entrantes y actualizar la lista
    _socketService.socket?.on('receive_message', (data) {
      setState(() {
        messages.add(data);
      });
    });
  }

  @override
  void dispose() {
    _socketService.disconnect();  // Desconectar al salir de la pantalla
    super.dispose();
  }

  // Función para enviar el mensaje
  void sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      _socketService.sendMessage('Usuario', message);  // Enviar mensaje
      setState(() {
        messages.add('Tú: $message');
        _messageController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Column(
        children: [
          // Esta es la lista de mensajes en el chat
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(messages[index]),
                );
              },
            ),
          ),
          // Caja de texto y botón de enviar mensaje
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: sendMessage,  // Enviar mensaje
                ),
              ],
            ),
          ),
        ],
      ),
      // Aquí es donde agregamos la CustomNavbar
      bottomNavigationBar: CustomNavbar(
        currentIndex: 2,  // Si quieres que el ícono de "Chat" esté seleccionado
        onTap: (index) {
          // Aquí manejas la lógica cuando se cambia de ítem en la navbar
          if (index == 0) {
            Navigator.pushNamed(context, '/mapa');
          }
          // Puedes agregar lógica similar para otros índices de la navbar
        },
      ),
    );
  }
}
