import 'package:flutter/material.dart';
import 'package:BioRuta/navbar_widget.dart'; // Importa tu navbar

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Center(
        child: const Text('Aquí va el contenido del chat'),
      ),
      // Aquí es donde agregamos la CustomNavbar
      bottomNavigationBar: CustomNavbar(
        currentIndex: 2, // Si quieres que el ícono de "Chat" esté seleccionado
        onTap: (index) {
          // Aquí manejas la lógica cuando se cambia de ítem en la navbar
          if (index == 0) {
            // Navegar a "Buscar"
            Navigator.pushNamed(context, '/mapa');
          }
          // Puedes agregar lógica similar para otros índices de la navbar
        },
      ),
    );
  }
}
