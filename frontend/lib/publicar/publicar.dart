import 'package:flutter/material.dart';
import '../navbar_widget.dart';
import 'publicar_viaje_paso1.dart';

class PublicarPage extends StatefulWidget {
  const PublicarPage({super.key});
  
  @override
  PublicarPageState createState() => PublicarPageState();
}

class PublicarPageState extends State<PublicarPage> {
  int _selectedIndex = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: const Text('Publicar Viaje'),
        backgroundColor: const Color(0xFF854937),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/inicio');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            
            // Título principal
            const Text(
              '¡Comparte tu viaje!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF854937),
              ),
            ),
            
            const SizedBox(height: 10),
            
            const Text(
              'Ayuda a otros estudiantes y ahorra en combustible',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B3B2D),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            // Icono central
            Container(
              width: 120,
              height: 120,              decoration: BoxDecoration(
                color: const Color(0xFF854937).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.directions_car,
                size: 60,
                color: Color(0xFF854937),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Información de pasos
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Proceso de publicación:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF854937),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildStepItem('1', 'Selecciona tu ruta'),
                  _buildStepItem('2', 'Elige fecha y hora'),
                  _buildStepItem('3', 'Configura el viaje'),
                  _buildStepItem('4', 'Revisa y publica'),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Botón para empezar
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PublicarViajePaso1(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF854937),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
                child: const Text(
                  'Comenzar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
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
              // Ya estamos en publicar
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/chat');
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/ranking');
              break;
            case 5:
              Navigator.pushReplacementNamed(context, '/perfil');
              break;
          }
        },
      ),
    );
  }

  Widget _buildStepItem(String number, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF854937),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6B3B2D),
            ),
          ),
        ],
      ),
    );
  }
}