import 'package:flutter/material.dart';
import '../navbar_widget.dart'; // Asegúrate de importar tu widget personalizado

class Perfil extends StatefulWidget {
  @override
  Perfil_ createState() => Perfil_();
}

class Perfil_ extends State<Perfil> {
  int _selectedIndex = 4; // índice del navbar (Perfil es el 4)

  @override
  Widget build(BuildContext context) {
    final Color fondo = Color(0xFFF8F2EF); // beige claro
    final Color primario = Color(0xFF6B3B2D); // marrón fuerte
    final Color secundario = Color(0xFF8D4F3A); // terracota suave

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: fondo,
        elevation: 0,
        title: Text('Perfil', style: TextStyle(color: primario)),
        iconTheme: IconThemeData(color: primario),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // Configuraciones futuras
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Tarjeta de perfil
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFF3D5C0),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('assets/profile.png'),
                  ),
                  SizedBox(height: 8),
                  Text('Miguelito', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primario)),
                  Text('39 años', style: TextStyle(color: secundario)),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Icon(Icons.emoji_emotions, color: secundario),
                          SizedBox(height: 4),
                          Text('22', style: TextStyle(color: primario, fontWeight: FontWeight.bold)),
                          Text('Recomendaciones', style: TextStyle(color: secundario, fontSize: 12)),
                        ],
                      ),
                      Column(
                        children: [
                          Icon(Icons.star, color: secundario),
                          SizedBox(height: 4),
                          Text('Principiante', style: TextStyle(color: primario, fontWeight: FontWeight.bold)),
                          Text('Nivel de experiencia', style: TextStyle(color: secundario, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Sobre Mi
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sobre Mi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primario)),
                  SizedBox(height: 8),
                  Text(
                    '• Soy una persona sencilla, con ganas de aprender y crecer cada día. Me gusta compartir momentos con mis amigos y disfrutar de las cosas simples de la vida. Siempre trato de ver el lado positivo y de aportar buena onda a donde voy. ¡Aquí para lo que sea, listo para nuevas aventuras!',
                    style: TextStyle(color: secundario, height: 1.5),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Carrera
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Carrera', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primario)),
                  SizedBox(height: 8),
                  Text('• Actor', style: TextStyle(color: secundario)),
                ],
              ),
            ),
          ],
        ),
      ),

      /// Aquí va tu CustomNavbar, igual que en `MapPage`
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
              Navigator.pushReplacementNamed(context, '/chat');
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
