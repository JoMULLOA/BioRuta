import 'package:flutter/material.dart';
import 'mapa_viajes_interactivo.dart';
import '../navbar_widget.dart';

class MapaViajesScreen extends StatefulWidget {
  const MapaViajesScreen({super.key});

  @override
  State<MapaViajesScreen> createState() => _MapaViajesScreenState();
}

class _MapaViajesScreenState extends State<MapaViajesScreen> {
  int _selectedIndex = 1; // Mapa is index 1 in navbar
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/inicio');
        break;
      case 1:
        // Ya estamos en mapa
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
        Navigator.pushReplacementNamed(context, '/perfil');
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
      bottomNavigationBar: CustomNavbar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
