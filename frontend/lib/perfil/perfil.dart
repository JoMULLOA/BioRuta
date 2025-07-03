import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../navbar_widget.dart';
import '../chat/Chatsoporte.dart';
import './solicitudes.dart';
import '../config/confGlobal.dart';
import 'ajustes.dart';

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
          //Agregar icono de solicitud de amistad
          IconButton(
            icon: Icon(Icons.person_add),
            tooltip: 'Solicitudes de amistad',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Solicitud()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.support_agent),
            tooltip: 'Soporte',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChatSoporte()),
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
                      color: Color(0xFFF3D5C0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: AssetImage('assets/profile.png'),
                          child: _userName.isEmpty
                              ? Icon(Icons.person, size: 40, color: secundario)
                              : null,
                        ),
                        SizedBox(height: 8),
                        Text(
                          _userName.isNotEmpty ? _userName : _userEmail,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primario,
                          ),
                        ),
                        Text(_userAge, style: TextStyle(color: secundario)),
                        if (_userEmail.isNotEmpty && _userName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _userEmail,
                              style: TextStyle(color: secundario, fontSize: 12),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.star, color: secundario, size: 16), // Ícono de estrella
                            SizedBox(width: 8), // Espaciado entre el ícono y el texto
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Clasificación',
                                  style: TextStyle(color: secundario, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '$_userclasificacion/5',
                                  style: TextStyle(color: secundario, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],

                    ),
                  ),

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