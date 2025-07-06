import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_navbar_con_notificaciones.dart';
import '../chat/Chatsoporte.dart';
import './amistad_menu.dart';
import '../config/confGlobal.dart';
import 'ajustes.dart';
import 'editar_perfil.dart';

class Perfil extends StatefulWidget {
  @override
  Perfil_ createState() => Perfil_();
}

class Perfil_ extends State<Perfil> {
  int _selectedIndex = 5;

  // Variables para almacenar datos del usuario
  String _userEmail = 'Cargando...';
  String _userName = 'Cargando...';
  String _userAge = 'Cargando...';
  String _userCareer = 'Cargando...';
  String _userDescription = 'Cargando...';
  //El de valoracion
  String _userclasificacion = 'Cargando...';
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
        
        // Debug: imprimir la respuesta completa
        print('Respuesta completa del servidor: $data');
        
        // Verificar si existe 'success' y si es true
        if (data != null && data['success'] == true) {
          final userData = data['data'];
          print('Datos del usuario recibidos: $userData');
          
          // Calcular edad desde fechaNacimiento si existe
          String userAge = 'Edad no especificada';
          if (userData['fechaNacimiento'] != null) {
            try {
              DateTime birthDate = DateTime.parse(userData['fechaNacimiento']);
              int age = DateTime.now().year - birthDate.year;
              userAge = '$age años';
            } catch (e) {
              print('Error calculando edad: $e');
            }
          }
          
          // Calcular clasificación usando método bayesiano
          String clasificacionFinal = 'Sin clasificación';
          if (userData['clasificacion'] != null) {
            double clasificacionOriginal = double.parse(userData['clasificacion'].toString());
            int cantidadValoraciones = userData['cantidadValoraciones'] ?? 1; // Usar 1 como mínimo
            
            // Llamar al método bayesiano
            double? clasificacionBayesiana = await _calcularCalificacionBayesiana(
              clasificacionOriginal,
              cantidadValoraciones
            );
            
            if (clasificacionBayesiana != null) {
              clasificacionFinal = clasificacionBayesiana.toStringAsFixed(1);
              print('Clasificación original: $clasificacionOriginal');
              print('Clasificación bayesiana: $clasificacionBayesiana');
            } else {
              // Si falla el cálculo bayesiano, usar la clasificación original
              clasificacionFinal = clasificacionOriginal.toStringAsFixed(1);
            }
          }
          
          setState(() {
            _userEmail = userData['email'] ?? 'Sin email';
            _userName = userData['nombreCompleto'] ?? 'Nombre no especificado';
            _userAge = userAge;
            _userCareer = userData['carrera'] ?? 'Carrera no especificada';
            _userDescription = userData['descripcion'] ?? 'Sin descripción';
            _userclasificacion = clasificacionFinal;
            _isLoading = false;
          });
        } else {
          print('Success no es true o data es null');
          setState(() {
            _isLoading = false;
            _userEmail = 'Error en la respuesta del servidor';
          });
        }
      } else if (response.statusCode == 304) {
        // Manejar caché del navegador
        print('Respuesta desde caché (304)');
        setState(() {
          _isLoading = false;
          _userEmail = 'Datos desde caché';
        });
      } else {
        print('Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Error del servidor: ${response.statusCode}');
    }} catch (error) {
      print('Error al cargar datos del usuario: $error');
      setState(() {
        _isLoading = false;
        _userEmail = 'Error al cargar datos';
      });
    }
  }

  // Método para calcular la calificación bayesiana
  Future<double?> _calcularCalificacionBayesiana(double promedioUsuario, int cantidadValoraciones) async {
    try {
      // Primero obtener el promedio global dinámico
      double promedioGlobal = await _obtenerPromedioGlobal();
      
      const int minimoValoraciones = 2; // Mínimo de valoraciones para considerar confiable
      
      final response = await http.post(
        Uri.parse('${confGlobal.baseUrl}/user/calcularCalificacion'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'promedioUsuario': promedioUsuario,
          'cantidadValoraciones': cantidadValoraciones,
          'promedioGlobal': promedioGlobal,
          'minimoValoraciones': minimoValoraciones,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['success'] == true) {
          return data['data']['calificacionAjustada']?.toDouble();
        }
      }
      
      print('Error en cálculo bayesiano: ${response.statusCode}');
      print('Response body: ${response.body}');
      return null;
    } catch (error) {
      print('Error al calcular calificación bayesiana: $error');
      return null;
    }
  }

  // Nuevo método para obtener el promedio global desde el backend
  Future<double> _obtenerPromedioGlobal() async {
    try {
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/user/promedioGlobal'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['success'] == true) {
          double promedioGlobal = data['data']['promedioGlobal']?.toDouble() ?? 3.0;
          print('Promedio global obtenido: $promedioGlobal');
          return promedioGlobal;
        }
      }
      
      print('Error obteniendo promedio global: ${response.statusCode}');
      print('Response body: ${response.body}');
      // En caso de error, retornar valor por defecto
      return 3.0;
    } catch (error) {
      print('Error al obtener promedio global: $error');
      // En caso de error, retornar valor por defecto
      return 3.0;
    }
  }

  // Función para navegar a la página de editar perfil
  void _navigateToEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditarPerfilPage()),
    );
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
        title: Text('Perfil', style: TextStyle(color: primario)),
        iconTheme: IconThemeData(color: primario),
        actions: [
          //Botón de amistades
          IconButton(
            icon: Icon(Icons.people),
            tooltip: 'Amistades',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AmistadMenuScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Configuración y Cerrar Sesión',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogoutPage()),
              );
            },
          )
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
                physics: AlwaysScrollableScrollPhysics(), // Permite scroll incluso si el contenido no es largo
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Tarjeta de perfil
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF8D4F3A), // Color secundario (marrón medio)
                            Color(0xFF6B3B2D), // Color primario (marrón oscuro)
                            Color(0xFFA0613B), // Marrón más claro para transición
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
                      child: Stack(
                        children: [
                          // Ícono de editar flotante en la esquina superior derecha
                          Positioned(
                            top: -8,
                            right: -8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: secundario, 
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () => _navigateToEditProfile(context),
                                icon: Icon(Icons.edit, color: Colors.white, size: 20), // Ícono marrón
                                padding: EdgeInsets.all(8),
                                constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                                tooltip: 'Editar Perfil',
                              ),
                            ),
                          ),
                          // Contenido original de la tarjeta
                          Column(
                      children: [
                        CircleAvatar(
                          radius: 45, // Aumenté un poco el tamaño
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: AssetImage('assets/profile.png'),
                          child: _userName.isEmpty
                              ? Icon(Icons.person, size: 45, color: Colors.white70)
                              : null,
                        ),
                        SizedBox(height: 12),
                        Text(
                          _userName.isNotEmpty ? _userName : _userEmail,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Texto blanco
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _userAge, 
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                        if (_userEmail.isNotEmpty && _userName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _userEmail,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8), 
                                fontSize: 13,
                              ),
                            ),
                          ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star, color: Color(0xFFFFD700), size: 18), // Estrella dorada
                              SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Clasificación',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9), 
                                      fontSize: 12, 
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '$_userclasificacion/5',
                                    style: TextStyle(
                                      color: Colors.white, 
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                          ], // Cierra Row de clasificación
                        ), // Cierra Column del contenido del Stack
                      ], // Cierra children del Stack
                    ), // Cierra Stack
                  ), // Cierra Container

                  SizedBox(height: 20),

                  // Sobre Mi
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
                          'Sobre Mi',
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

                  // Carrera
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
                          'Carrera',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primario,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• $_userCareer',
                          style: TextStyle(color: secundario),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatSoporte(),
            ),
          );
        },
        backgroundColor: primario,
        child: Icon(Icons.support_agent, color: Colors.white),
        tooltip: 'Gestionar Amistades',
      ),
      bottomNavigationBar: CustomNavbarConNotificaciones(
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
              // Ir al mapa
              Navigator.pushReplacementNamed(context, '/mapa');
              break;
            case 2:
              // Publicar viaje (por implementar)
              Navigator.pushReplacementNamed(context, '/publicar');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/chat');
              break;
            case 4:
              // Perfil (por implementar)
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
}