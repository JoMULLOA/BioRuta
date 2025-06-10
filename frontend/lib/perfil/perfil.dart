import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../navbar_widget.dart';
import '../chat/Chatsoporte.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Método para cargar datos del usuario desde backend
  Future<void> _loadUserData() async {
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
        Uri.parse('http://localhost:3000/api/user/busqueda?email=$email'), 
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
          
          setState(() {
            _userEmail = userData['email'] ?? 'Sin email';
            _userName = userData['nombreCompleto'] ?? 'Nombre no especificado';
            _userAge = userAge;
            _userCareer = userData['carrera'] ?? 'Carrera no especificada';
            _userDescription = userData['descripcion'] ?? 'Sin descripción';
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
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadUserData();
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // Configuraciones futuras
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
          : SingleChildScrollView(
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
      bottomNavigationBar: CustomNavbar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == _selectedIndex) return;

          setState(() {
            _selectedIndex = index;
          });

          switch (index) {
            case 0:
              // Ya estamos en inicio, no hacer nada
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