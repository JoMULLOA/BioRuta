import 'package:flutter/material.dart';
import '../navbar_widget.dart'; // Asegúrate de importar tu navbar
import 'pagina_individual.dart'; // Importa la página individual

class Chat extends StatefulWidget {
  @override
  ChatState createState() => ChatState();
}

class ChatState extends State<Chat> {
  final List<Map<String, String>> chatsAmigos = [
    {'nombre': 'Antonieta', 'mensaje': '¿Vamos al BioRuta hoy?'},
    {'nombre': 'Esteban', 'mensaje': 'Bro revisa la app pls'},
    {'nombre': 'Mateo', 'mensaje': 'Papá, ¿jugamos?'},
    {'nombre': 'Luzmira', 'mensaje': 'Te hice pan amasado ❤️'},
  ];

  int _selectedIndex = 3; // índice del chat en el navbar

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
        title: Text('Chats', style: TextStyle(color: principal)),
        iconTheme: IconThemeData(color: principal),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            // Chat importante
            Card(
              color: Colors.brown.shade100.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: Icon(Icons.star, color: secundario),
                title: Text('Chat de Viaje', style: TextStyle(color: principal, fontWeight: FontWeight.bold)),
                subtitle: Text('Donde estás que no te veo', style: TextStyle(color: secundario)),
                onTap: () => Navigator.pushNamed(context, '/chatImportante'),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Amistades',
              style: TextStyle(color: principal, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),

            // Generar lista de chats con amigos
            ...chatsAmigos.map((chat) {
              return Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: principal.withOpacity(0.8),
                    child: Text(chat['nombre']![0], style: TextStyle(color: Colors.white)),
                  ),
                  title: Text(chat['nombre']!, style: TextStyle(color: principal)),
                  subtitle: Text(chat['mensaje']!, style: TextStyle(color: secundario)),
                  onTap: () {
                    // Aquí navegamos a la página individual del chat usando MaterialPageRoute
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaginaIndividual(nombre: chat['nombre']!),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ],
        ),
      ),
      bottomNavigationBar: CustomNavbar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == _selectedIndex) return;

          setState(() {
            _selectedIndex = index;
          });

          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/inicio');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/mapa');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/publicar');
              break;
            case 3:
              // Ya estás en chat
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/perfil');
              break;
          }
        },
      ),
    );
  }
}
