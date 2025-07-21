import 'package:flutter/material.dart';

class CustomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool showSOS; // Nueva propiedad para controlar el botón SOS

  const CustomNavbar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.showSOS = false, // Por defecto no mostrar SOS
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Lista base de items sin SOS
    List<BottomNavigationBarItem> items = const [
      BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Viajes'),
      BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
      BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Publicar'),
      BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
      BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Ranking'),
      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
    ];

    // Si showSOS es true, insertar el botón SOS en el medio (después de Publicar)
    if (showSOS) {
      items = [
        const BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Viajes'),
        const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
        const BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Publicar'),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.emergency,
              color: Colors.white,
              size: 20,
            ),
          ),
          label: 'SOS',
          activeIcon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  spreadRadius: 3,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.emergency,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Ranking'),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ];
    }

    return BottomNavigationBar(
      currentIndex: currentIndex.clamp(0, items.length - 1), // 🔒 PROTECCIÓN: Asegurar que el índice esté en rango válido
      selectedItemColor: const Color(0xFF854937),
      unselectedItemColor: const Color(0xFF070505).withOpacity(0.5),
      backgroundColor: const Color(0xFFF2EEED),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      onTap: onTap,
      items: items,
    );
  }
}
