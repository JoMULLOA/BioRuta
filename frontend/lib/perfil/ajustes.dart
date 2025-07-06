import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/token_manager.dart';
import '../config/confGlobal.dart';
import '../auth/login.dart';
import 'mis_vehiculos.dart';

class LogoutPage extends StatelessWidget {
  const LogoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color fondo = Color(0xFFF8F2EF);
    final Color primario = Color(0xFF6B3B2D);
    final Color secundario = Color(0xFF8D4F3A);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: fondo,
        elevation: 0,
        title: Text('Configuración', style: TextStyle(color: primario)),
        iconTheme: IconThemeData(color: primario),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Spacer(),

            // Botón de mis vehículos
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: () => _navigateToVehiculos(context),
                icon: Icon(Icons.directions_car, color: Colors.white),
                label: Text(
                  'Mis Vehículos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: secundario,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            // Botón de cerrar sesión centrado
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                icon: Icon(Icons.logout, color: Colors.white),
                label: Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            Spacer(),

            // Información de la app
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'BioRuta',
                    style: TextStyle(
                      color: primario,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Versión 1.0.0',
                    style: TextStyle(
                      color: secundario,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Navegar a la página de mis vehículos
  void _navigateToVehiculos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MisVehiculosPage()),
    );
  }

  // Mostrar diálogo de confirmación para cerrar sesión
  void _showLogoutDialog(BuildContext context) {
    final Color primario = Color(0xFF6B3B2D);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[600]),
              SizedBox(width: 12),
              Text(
                'Cerrar Sesión',
                style: TextStyle(color: primario),
              ),
            ],
          ),
          content: Text(
            '¿Estás seguro de que quieres cerrar sesión?\n\nTendrás que volver a iniciar sesión para acceder a tu cuenta.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performLogout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );
  }

  // Función para realizar el logout
  Future<void> _performLogout(BuildContext context) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B3B2D)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cerrando sesión...',
                    style: TextStyle(
                      color: Color(0xFF6B3B2D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Intentar hacer logout en el backend primero
      await _logoutFromBackend();

      // Limpiar todos los datos de autenticación locales
      await TokenManager.clearAuthData();

      // Limpiar cualquier otro dato local adicional si es necesario
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Esto limpia todas las preferencias compartidas

      // Cerrar el diálogo de carga
      Navigator.of(context).pop();

      // Navegar al login y limpiar toda la pila de navegación
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );

      // Mostrar mensaje de confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Sesión cerrada exitosamente'),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      // Cerrar el diálogo de carga en caso de error
      Navigator.of(context).pop();
      
      print('Error durante el logout: $e');
      
      // Incluso si hay error en el backend, limpiar datos locales
      await TokenManager.clearAuthData();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Navegar al login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
      
      // Mostrar mensaje de advertencia pero continuar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Sesión cerrada localmente (problema de conexión)')),
            ],
          ),
          backgroundColor: Colors.orange[600],
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Función para hacer logout en el backend
  Future<void> _logoutFromBackend() async {
    try {
      // Obtener headers de autenticación
      final headers = await TokenManager.getAuthHeaders();
      
      if (headers != null) {
        final response = await http.post(
          Uri.parse('${confGlobal.baseUrl}/auth/logout'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          print('✅ Logout exitoso en el backend');
          final data = json.decode(response.body);
          print('Respuesta del servidor: ${data['message']}');
        } else {
          print('⚠️ Error en logout del backend: ${response.statusCode}');
          print('Respuesta: ${response.body}');
        }
      } else {
        print('⚠️ No hay token válido para logout en backend');
      }
    } catch (e) {
      print('❌ Error conectando con backend para logout: $e');
      // No lanzar excepción aquí - permitir que el logout local continúe
    }
  }
}
