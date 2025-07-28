import 'package:flutter/material.dart';
import '../services/viaje_service.dart';
import '../mis_viajes/detalle_viaje_conductor_screen.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Navegar a una ruta específica
  static Future<void> navigateTo(String route) async {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      print('🔄 Navegando a: $route');
      await navigator.pushNamed(route);
    } else {
      print('❌ Navigator no disponible para navegar a: $route');
    }
  }

  /// Navegar y reemplazar la ruta actual
  static Future<void> navigateAndReplace(String route) async {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      print('🔄 Navegando y reemplazando a: $route');
      await navigator.pushReplacementNamed(route);
    } else {
      print('❌ Navigator no disponible para navegar a: $route');
    }
  }

  /// Navegar a la pantalla de amistades
  static Future<void> navigateToFriends() async {
    await navigateTo('/amistades');
  }

  /// Navegar a la pantalla de solicitudes
  static Future<void> navigateToRequests() async {
    await navigateTo('/solicitudes');
  }

  /// Navegar al panel de administrador en la sección de soporte
  static Future<void> navigateToAdminPanel() async {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      print('🔄 Navegando al panel de administrador - sección soporte');
      // Navegar al admin dashboard con argumentos para ir a la pestaña de soporte
      await navigator.pushNamed('/admin', arguments: {'initialTab': 3}); // Tab 3 = Soporte
    } else {
      print('❌ Navigator no disponible para navegar al panel de administrador');
    }
  }

  /// Navegar al detalle del viaje específico
  static Future<void> navigateToTripDetail(String viajeId) async {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      print('🔄 Navegando al detalle del viaje: $viajeId');
      
      try {
        // Obtener todos los viajes del usuario para encontrar el específico
        final misViajes = await ViajeService.obtenerMisViajes();
        
        // Buscar el viaje específico por ID
        final viaje = misViajes.firstWhere(
          (v) => v.id == viajeId,
          orElse: () => throw Exception('Viaje no encontrado'),
        );
        
        // Navegar al detalle del viaje con el objeto completo
        await navigator.push(
          MaterialPageRoute(
            builder: (context) => DetalleViajeConductorScreen(viaje: viaje),
          ),
        );
      } catch (e) {
        print('❌ Error obteniendo detalle del viaje: $e');
        // Fallback: navegar a la pantalla de solicitudes/notificaciones
        await navigateToRequests();
      }
    } else {
      print('❌ Navigator no disponible para navegar al detalle del viaje');
    }
  }

  /// Obtener el contexto actual del navigator
  static BuildContext? get currentContext => navigatorKey.currentContext;
}
