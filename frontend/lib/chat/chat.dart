import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Importa SecureStorage

import '../../navbar_widget.dart';
import 'pagina_individual.dart';
import '../models/user_models.dart';

class Chat extends StatefulWidget {
  @override
  ChatState createState() => ChatState();
}

class ChatState extends State<Chat> {
  // --- Variables de Estado para la UI ---
  List<User> amigosDisponibles = [];
  bool isLoading = true;
  String? errorMessage;
  int _selectedIndex = 3;

  // --- Configuraciones de la API ---
  final String _baseUrl = 'http://10.0.2.2:3000';

  // --- Variables para el token y RUT (ahora NO hardcodeadas) ---
  String? _jwtToken; // Será nulo hasta que se cargue
  String? _rutUsuarioAutenticado; // Será nulo hasta que se cargue

  // Instancia de FlutterSecureStorage
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    // Primero carga el token y el RUT, luego carga los amigos
    _initChatScreen();
  }

  Future<void> _initChatScreen() async {
    await _loadAuthData(); // Carga el token y el RUT
    if (_jwtToken != null && _rutUsuarioAutenticado != null) {
      await _cargarAmigosDisponibles(); // Solo carga amigos si hay token y RUT
    } else {
      setState(() {
        isLoading = false;
        errorMessage = 'Error: No se pudo cargar el token o el RUT del usuario. Por favor, reinicia la sesión.';
      });
      print('ERROR: Token o RUT nulo al iniciar ChatScreen.');
    }
  }

  // --- Nueva función para cargar el token y RUT desde SecureStorage ---
  Future<void> _loadAuthData() async {
    try {
      _jwtToken = await _storage.read(key: 'jwt_token');
      _rutUsuarioAutenticado = await _storage.read(key: 'user_rut');

      print('DEBUG: Token cargado del storage: ${_jwtToken != null ? _jwtToken!.substring(0, _jwtToken!.length > 10 ? 10 : _jwtToken!.length) : "Nulo"}...');
      print('DEBUG: RUT cargado del storage: $_rutUsuarioAutenticado');

    } catch (e) {
      print('ERROR: Error al cargar token/rut de SecureStorage: $e');
      setState(() {
        errorMessage = 'Error al cargar datos de sesión: $e';
        isLoading = false;
      });
    }
  }

  // --- Función para cargar la lista de usuarios desde el backend ---
  Future<void> _cargarAmigosDisponibles() async {
    // Asegurarse de que el token esté disponible antes de la petición
    if (_jwtToken == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'No hay token de autenticación disponible. Por favor, vuelve a iniciar sesión.';
      });
      print('ERROR: _cargarAmigosDisponibles llamado sin token JWT.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final Uri requestUri = Uri.parse('$_baseUrl/api/users');
      
      print('DEBUG: Intentando hacer GET a: $requestUri');
      print('DEBUG: Con token (primeros 10 chars): ${_jwtToken!.substring(0, _jwtToken!.length > 10 ? 10 : _jwtToken!.length)}...');

      final response = await http.get(
        requestUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_jwtToken!.trim()}', // Usa el token cargado dinámicamente
        },
      );

      print('DEBUG: Código de estado de la respuesta: ${response.statusCode}');
      print('DEBUG: Cuerpo de la respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] is List) {
          final List<dynamic> usersJson = responseData['data'];
          setState(() {
            // Filtra al usuario actualmente autenticado de la lista
            amigosDisponibles = usersJson
                .map((json) => User.fromJson(json))
                .where((user) => user.rut != _rutUsuarioAutenticado) // Filtra por RUT
                .toList();
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Error en la estructura de datos recibida: ${responseData['message'] ?? 'Formato inesperado'}';
            isLoading = false;
          });
          print('ERROR: Formato de respuesta inesperado: $responseData');
        }
      } else {
        setState(() {
          errorMessage = 'Error al cargar usuarios: ${response.statusCode} - ${response.body}';
          isLoading = false;
        });
        print('ERROR: Fallo en la respuesta del servidor: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error de red o parseo: $e';
        isLoading = false;
      });
      print('ERROR: Excepción al intentar cargar amigos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Tu método build() permanece sin cambios) ...
    final Color fondo = const Color(0xFFF8F2EF);
    final Color principal = const Color(0xFF6B3B2D);
    final Color secundario = const Color(0xFF8D4F3A);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: fondo,
        elevation: 0,
        title: Text('Chats', style: TextStyle(color: principal)),
        iconTheme: IconThemeData(color: principal),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: principal))
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(errorMessage!, style: TextStyle(color: Colors.red)),
                        ElevatedButton(
                          onPressed: _cargarAmigosDisponibles,
                          child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: principal),
                        )
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      Card(
                        color: Colors.brown.shade100.withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: Icon(Icons.star, color: secundario),
                          title: Text('Chat de Viaje', style: TextStyle(color: principal, fontWeight: FontWeight.bold)),
                          subtitle: Text('Donde estás que no te veo', style: TextStyle(color: secundario)),
                          onTap: () => Navigator.pushNamed(context, '/chatImportante'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Amistades',
                        style: TextStyle(color: principal, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Generar la lista de chats con amigos DINÁMICAMENTE desde los usuarios obtenidos
                      ...amigosDisponibles.map((user) {
                        return Card(
                          color: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: principal.withOpacity(0.8),
                              child: Text(user.nombreCompleto[0], style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(user.nombreCompleto, style: TextStyle(color: principal)),
                            subtitle: Text(user.email, style: TextStyle(color: secundario)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PaginaIndividual(
                                    nombre: user.nombreCompleto,
                                    rutAmigo: user.rut,
                                    rutUsuarioAutenticado: _rutUsuarioAutenticado!, // Pasa el RUT del usuario autenticado aquí
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
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
              Navigator.pushReplacementNamed(context, '/inicio');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/mapa');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/publicar');
              break;
            case 3:
              break;
            case 4:
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