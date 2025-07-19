import 'package:flutter/material.dart';
import 'mapa_viajes_interactivo.dart';
import '../widgets/navbar_con_sos_dinamico.dart';

class MapaViajesScreen extends StatefulWidget {
  const MapaViajesScreen({super.key});

  @override
  State<MapaViajesScreen> createState() => _MapaViajesScreenState();
}

class _MapaViajesScreenState extends State<MapaViajesScreen> {
  int _selectedIndex = 1; // Buscar ahora está en index 1
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/mis-viajes');
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
        Navigator.pushReplacementNamed(context, '/ranking');
        break;
      case 5:
        Navigator.pushReplacementNamed(context, '/perfil'); // Perfil en índice 5 cuando no hay SOS
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: const Text('Viajes Disponibles'),
        backgroundColor: const Color(0xFF854937),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: const MapaViajesInteractivo(),
      bottomNavigationBar: NavbarConSOSDinamico(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
