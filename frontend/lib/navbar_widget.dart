import 'package:flutter/material.dart';

class CustomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavbar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: const Color(0xFF854937),
      unselectedItemColor: const Color(0xFF070505).withOpacity(0.5),
      backgroundColor: const Color(0xFFF2EEED),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Mis viajes'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
        BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Publicar'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Ranking'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }
}
