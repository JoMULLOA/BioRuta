import 'package:flutter/material.dart';

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

  /// Obtener el contexto actual del navigator
  static BuildContext? get currentContext => navigatorKey.currentContext;
}
