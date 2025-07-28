import 'package:flutter/material.dart';
import '../navbar_widget.dart';
import '../services/viaje_service.dart';
import '../services/emergencia_service.dart';

class NavbarConSOSDinamico extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const NavbarConSOSDinamico({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  State<NavbarConSOSDinamico> createState() => _NavbarConSOSDinamicoState();
}

class _NavbarConSOSDinamicoState extends State<NavbarConSOSDinamico> {
  bool _mostrarSOS = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _verificarViajesActivos();
    // Verificar cada 30 segundos si hay cambios en los viajes
    _iniciarTimerVerificacion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Verificar viajes cada vez que cambie la pantalla
    _verificarViajesActivos();
  }

  void _iniciarTimerVerificacion() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _verificarViajesActivos();
        _iniciarTimerVerificacion(); // Reiniciar el timer
      }
    });
  }

  Future<void> _verificarViajesActivos() async {
    try {
      debugPrint('🔄 Verificando viajes activos para navbar...');
      
      // Usar solo la lógica principal (ya no necesitamos el método de debug)
      final tieneViajes = await ViajeService.tieneViajesActivos();
      
      debugPrint('📊 Resultado tieneViajesActivos: $tieneViajes');
      debugPrint('🎯 Estado actual mostrarSOS: $_mostrarSOS');
      
      if (mounted) {
        setState(() {
          _mostrarSOS = tieneViajes;
          _cargando = false;
        });
        debugPrint('✅ Estado navbar actualizado: mostrarSOS = $_mostrarSOS');
      }
    } catch (e) {
      debugPrint('💥 Error al verificar viajes activos en navbar: $e');
      if (mounted) {
        setState(() {
          _mostrarSOS = false;
          _cargando = false;
        });
      }
    }
  }

  int _ajustarIndice(int index) {
    // Si SOS está visible y el índice es mayor o igual a 3 (SOS), 
    // ajustar el índice para la navegación
    if (_mostrarSOS && index >= 3) {
      // Si toca SOS (índice 3), navegar a pantalla SOS
      if (index == 3) {
        _navegarASOS();
        return widget.currentIndex; // No cambiar de pantalla
      }
      // Si toca Chat, Ranking o Perfil, decrementar índice
      return index - 1;
    }
    return index;
  }

  void _navegarASOS() async {
    // Obtener información del viaje activo para enviar en el SOS
    Map<String, dynamic>? infoViaje;
    try {
      debugPrint('🔍 Verificando viajes para navegación a SOS...');
      final tieneViajes = await ViajeService.tieneViajesActivos();
      debugPrint('📊 Tiene viajes activos: $tieneViajes');
      
      if (tieneViajes) {
        // Obtener detalles del viaje activo
        debugPrint('🔄 Obteniendo detalles del viaje activo...');
        infoViaje = await ViajeService.obtenerDetallesViajeActivo();
        debugPrint('📋 Info viaje obtenida: $infoViaje');
      } else {
        debugPrint('⚠️ No hay viajes activos para obtener detalles');
      }
    } catch (e) {
      debugPrint('💥 Error al obtener info del viaje para navegación SOS: $e');
    }
    
    debugPrint('🚀 Navegando a SOS con info: $infoViaje');
    Navigator.pushNamed(context, '/sos', arguments: {
      'infoViaje': infoViaje,
    });
  }

  void _manejarSOS() async {
    // Obtener información del viaje activo para enviar en el SOS
    Map<String, dynamic>? infoViaje;
    try {
      debugPrint('🔍 Verificando viajes para SOS...');
      final tieneViajes = await ViajeService.tieneViajesActivos();
      debugPrint('📊 Tiene viajes activos: $tieneViajes');
      
      if (tieneViajes) {
        // Obtener detalles del viaje activo
        debugPrint('🔄 Obteniendo detalles del viaje activo...');
        infoViaje = await ViajeService.obtenerDetallesViajeActivo();
        debugPrint('📋 Info viaje obtenida: $infoViaje');
      } else {
        debugPrint('⚠️ No hay viajes activos para obtener detalles');
      }
    } catch (e) {
      debugPrint('💥 Error al obtener info del viaje para SOS: $e');
    }
    
    debugPrint('� Activando emergencia desde navbar dinámico...');
    // Activar emergencia directamente desde aquí con la información del viaje
    await EmergenciaService.mostrarDialogoEmergenciaGlobal(
      context, 
      infoViaje: infoViaje
    );
  }

  // Método público para forzar actualización desde fuera
  void actualizarEstado() {
    _verificarViajesActivos();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      // Mostrar navbar sin SOS mientras carga
      return CustomNavbar(
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
        showSOS: false,
      );
    }

    int currentIndexAjustado = widget.currentIndex;
    
    // Si SOS está visible, ajustar el índice actual para la visualización
    if (_mostrarSOS && widget.currentIndex >= 3) {
      currentIndexAjustado = widget.currentIndex + 1;
    }

    return CustomNavbar(
      currentIndex: currentIndexAjustado,
      onTap: (index) {
        final indiceAjustado = _ajustarIndice(index);
        if (index == 3 && _mostrarSOS) {
          // Es el botón SOS, no llamar onTap del padre
          return;
        }
        widget.onTap(indiceAjustado);
      },
      showSOS: _mostrarSOS,
      onSOSLongPress: _manejarSOS, // Usar el método local que incluye info del viaje
    );
  }
}
