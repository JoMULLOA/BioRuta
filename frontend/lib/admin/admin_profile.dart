import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/confGlobal.dart';
import '../utils/token_manager.dart';
import '../auth/login.dart';

class AdminProfile extends StatefulWidget {
  const AdminProfile({super.key});

  @override
  State<AdminProfile> createState() => _AdminProfileState();
}

class _AdminProfileState extends State<AdminProfile> {
  // Variables para almacenar datos del usuario
  String _userEmail = 'Cargando...';
  String _userName = 'Cargando...';
  String _userDescription = 'Cargando...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Método específico para el refresh (pull to refresh)
  Future<void> _refreshUserData() async {
    await _loadUserDataInternal();
  }

  // Método público para cargar datos (inicial)
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    await _loadUserDataInternal();
  }

  // Método interno que hace la carga real de datos
  Future<void> _loadUserDataInternal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      
      if (email == null) {
        setState(() {
          _isLoading = false;
          _userEmail = 'Usuario no encontrado';
        });
        return;
      }

      // Llamada al backend
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/user/busqueda?email=$email'),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Verificar si existe 'success' y si es true
        if (data != null && data['success'] == true) {
          final userData = data['data'];
          
          setState(() {
            _userEmail = userData['email'] ?? 'Sin email';
            _userName = userData['nombreCompleto'] ?? 'Nombre no especificado';
            _userDescription = userData['descripcion'] ?? 'Administrador del sistema BioRuta';
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _userEmail = 'Error en la respuesta del servidor';
          });
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (error) {
      print('Error al cargar datos del usuario: $error');
      setState(() {
        _isLoading = false;
        _userEmail = 'Error al cargar datos';
      });
    }
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
            '¿Estás seguro de que quieres cerrar sesión?\n\nTendrás que volver a iniciar sesión para acceder al panel de administración.',
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
      await prefs.clear();

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
    }
  }

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
        title: Text('Perfil Administrador', style: TextStyle(color: primario)),
        iconTheme: IconThemeData(color: primario),
        automaticallyImplyLeading: false,
        actions: [
          //Botón de logout
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primario),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshUserData,
              color: primario,
              backgroundColor: fondo,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Tarjeta de perfil de administrador
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1565C0), // Azul administrador
                            Color(0xFF0D47A1), // Azul más oscuro
                            Color(0xFF1976D2), // Azul medio
                          ],
                          stops: [0.0, 0.7, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            spreadRadius: 2,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Icon(
                              Icons.admin_panel_settings,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            _userName.isNotEmpty ? _userName : _userEmail,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Administrador',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_userEmail.isNotEmpty && _userName.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _userEmail,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Información del administrador
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Descripción',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primario,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _userDescription,
                            style: TextStyle(color: secundario, height: 1.5),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Privilegios de administrador
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.security, color: primario),
                              SizedBox(width: 8),
                              Text(
                                'Privilegios de Administrador',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primario,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildPrivilegeItem('Gestión completa de usuarios'),
                          _buildPrivilegeItem('Acceso a estadísticas del sistema'),
                          _buildPrivilegeItem('Administración de contenido'),
                          _buildPrivilegeItem('Centro de soporte avanzado'),
                          _buildPrivilegeItem('Configuración del sistema'),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Información del sistema
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: primario),
                              SizedBox(width: 8),
                              Text(
                                'Información del Sistema',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primario,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            '• BioRuta v1.0\n'
                            '• Sistema de carpooling universitario\n'
                            '• Backend: Node.js + MongoDB\n'
                            '• Frontend: Flutter',
                            style: TextStyle(color: secundario, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPrivilegeItem(String privilege) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              privilege,
              style: TextStyle(
                color: Color(0xFF8D4F3A),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
