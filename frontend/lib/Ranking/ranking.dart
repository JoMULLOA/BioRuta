import 'package:flutter/material.dart';
import '../navbar_widget.dart'; // Asegúrate de importar tu navbar

class ranking extends StatefulWidget {
  @override
  State<ranking> createState() => _RankingState();
}

class _RankingState extends State<ranking> {
  int _selectedIndex = 4; // índice para Ranking

  final Color fondo = const Color(0xFFF8F2EF);
  final Color principal = const Color(0xFF6B3B2D);
  final Color secundario = const Color(0xFF8D4F3A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: fondo,
        elevation: 0,
        title: Text('Ranking', style: TextStyle(color: principal)),
        iconTheme: IconThemeData(color: principal),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Usuarios',
              style: TextStyle(color: principal, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  _buildRankingItem('Miguelito', 120, 1),
                  _buildRankingItem('Antonieta', 105, 2),
                  _buildRankingItem('Mateo', 88, 3),
                  _buildRankingItem('Esteban', 70, 4),
                ],
              ),
            ),
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

  Widget _buildRankingItem(String nombre, int puntos, int posicion) {
    IconData icono;
    Color color;

    switch (posicion) {
      case 1:
        icono = Icons.emoji_events;
        color = Colors.amber;
        break;
      case 2:
        icono = Icons.emoji_events;
        color = Colors.grey;
        break;
      case 3:
        icono = Icons.emoji_events;
        color = Colors.brown;
        break;
      default:
        icono = Icons.star_border;
        color = secundario;
        break;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.8),
          child: Icon(icono, color: Colors.white),
        ),
        title: Text(nombre, style: TextStyle(color: principal, fontWeight: FontWeight.bold)),
        subtitle: Text('Puntos: $puntos', style: TextStyle(color: secundario)),
        trailing: Text('#$posicion', style: TextStyle(color: principal, fontSize: 16)),
      ),
    );
  }
}
