import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notificacion_service.dart';
import '../providers/theme_provider.dart';
import '../config/app_colors.dart';

class CustomNavbarConNotificaciones extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavbarConNotificaciones({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  _CustomNavbarConNotificacionesState createState() => _CustomNavbarConNotificacionesState();
}

class _CustomNavbarConNotificacionesState extends State<CustomNavbarConNotificaciones> {
  int _numeroNotificaciones = 0;

  @override
  void initState() {
    super.initState();
    _cargarNotificaciones();
    // Actualizar notificaciones cada 30 segundos
    _startNotificationTimer();
  }

  Future<void> _cargarNotificaciones() async {
    try {
      final numero = await NotificacionService.obtenerNumeroNotificacionesPendientes();
      if (mounted) {
        setState(() {
          _numeroNotificaciones = numero;
        });
      }
    } catch (e) {
      print('Error al cargar notificaciones: $e');
    }
  }

  void _startNotificationTimer() {
    Future.delayed(Duration(seconds: 30), () {
      if (mounted) {
        _cargarNotificaciones();
        _startNotificationTimer(); // Reiniciar el timer
      }
    });
  }

  Widget _buildProfileIconWithBadge() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.person),
        if (_numeroNotificaciones > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _numeroNotificaciones > 99 ? '99+' : _numeroNotificaciones.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final selectedColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
        final unselectedColor = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
        final backgroundColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
        
        return BottomNavigationBar(
          currentIndex: widget.currentIndex,
          selectedItemColor: selectedColor,
          unselectedItemColor: unselectedColor,
          backgroundColor: backgroundColor,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          onTap: widget.onTap,
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Viajes'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
        BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Publicar'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Ranking'),
        BottomNavigationBarItem(
          icon: _buildProfileIconWithBadge(),
          label: 'Perfil',
        ),
      ],
        );
      },
    );
  }
}
