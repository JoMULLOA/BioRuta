import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'services/emergencia_service.dart';
import 'providers/theme_provider.dart';
import 'config/app_colors.dart';

class CustomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool showSOS; // Nueva propiedad para controlar el botón SOS
  final VoidCallback? onSOSLongPress; // Callback para long press en SOS

  const CustomNavbar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.showSOS = false, // Por defecto no mostrar SOS
    this.onSOSLongPress, // Callback opcional para SOS
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
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
          icon: _buildSOSButton(),
          label: 'SOS',
          activeIcon: _buildSOSButton(isActive: true),
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Ranking'),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ];
    }

        return BottomNavigationBar(
          currentIndex: currentIndex.clamp(0, items.length - 1),
          selectedItemColor: themeProvider.isDarkMode 
              ? AppColors.primaryDark 
              : AppColors.primaryLight,
          unselectedItemColor: themeProvider.isDarkMode
              ? AppColors.darkSecondaryText
              : AppColors.lightSecondaryText,
          backgroundColor: themeProvider.isDarkMode
              ? AppColors.darkSurface
              : Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          onTap: onTap,
          items: items,
        );
      },
    );
  }

  Widget _buildSOSButton({bool isActive = false}) {
    return _SOSButtonWidget(
      onLongPress: onSOSLongPress,
      isActive: isActive,
    );
  }
}

class _SOSButtonWidget extends StatefulWidget {
  final VoidCallback? onLongPress;
  final bool isActive;

  const _SOSButtonWidget({
    this.onLongPress,
    this.isActive = false,
  });

  @override
  State<_SOSButtonWidget> createState() => _SOSButtonWidgetState();
}

class _SOSButtonWidgetState extends State<_SOSButtonWidget>
    with SingleTickerProviderStateMixin {
  Timer? _longPressTimer;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isLongPressActivated = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    HapticFeedback.lightImpact();
    _scaleController.forward();
    _isLongPressActivated = false;
    
    // Iniciar timer de 2 segundos para long press
    _longPressTimer = Timer(const Duration(seconds: 2), () {
      _isLongPressActivated = true;
      HapticFeedback.heavyImpact();
      
      if (widget.onLongPress != null) {
        // Usar callback específico si está disponible
        widget.onLongPress!();
      } else {
        // Usar método global si no hay callback específico
        EmergenciaService.mostrarDialogoEmergenciaGlobal(context);
      }
    });
  }

  void _onTapUp(TapUpDetails details) {
    _longPressTimer?.cancel();
    _scaleController.reverse();
    
    // Si no se activó el long press, es un tap normal
    if (!_isLongPressActivated) {
      // Navegar a la pantalla SOS
      Navigator.pushNamed(context, '/sos');
    }
  }

  void _onTapCancel() {
    _longPressTimer?.cancel();
    _scaleController.reverse();
    _isLongPressActivated = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(widget.isActive ? 0.5 : 0.3),
                    spreadRadius: widget.isActive ? 3 : 2,
                    blurRadius: widget.isActive ? 6 : 4,
                    offset: Offset(0, widget.isActive ? 3 : 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.emergency,
                color: Colors.white,
                size: 20,
              ),
            ),
          );
        },
      ),
    );
  }
}
