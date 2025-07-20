import 'package:flutter/material.dart';
import '../services/notificacion_service.dart';
import '../perfil/notificaciones.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool showNotifications;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.showNotifications = true,
  }) : super(key: key);

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CustomAppBarState extends State<CustomAppBar> {
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.showNotifications) {
      _cargarConteoNotificaciones();
    }
  }

  Future<void> _cargarConteoNotificaciones() async {
    try {
      final count = await NotificacionService.obtenerNumeroNotificacionesPendientes();
      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      // Error silencioso, no mostrar al usuario
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(widget.title),
      backgroundColor: const Color(0xFF854937),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: widget.showNotifications
          ? [
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications),
                    onPressed: () async {
                      // Navegar a notificaciones
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificacionesScreen(),
                        ),
                      );
                      // Recargar conteo después de regresar
                      _cargarConteoNotificaciones();
                    },
                  ),
                  if (_notificationCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_notificationCount',
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
              ),
            ]
          : null,
    );
  }
}
