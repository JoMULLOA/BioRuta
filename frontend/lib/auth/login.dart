import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; // Importa el decodificador JWT
import 'verificacion.dart';
import '../buscar/inicio.dart';
import './recuperacion.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/confGlobal.dart';
import '../utils/token_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool cargando = false;
  bool verClave = false;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Configuración: cambiar a true para habilitar auto-login
  static const bool AUTO_LOGIN_ENABLED = false;

  @override
  void initState() {
    super.initState();
    
    if (AUTO_LOGIN_ENABLED) {
      _checkAndRedirectIfAuthenticated();
    } else {
      // Solo limpiar tokens expirados sin redireccionar automáticamente
      _cleanExpiredTokenOnly();
    }
  }

  // Verificar autenticación y redireccionar si es válida (solo si AUTO_LOGIN_ENABLED = true)
  Future<void> _checkAndRedirectIfAuthenticated() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      
      if (token == null) {
        print('🔒 No hay token almacenado');
        return;
      }

      // Verificar si el token ha expirado según el cliente
      if (JwtDecoder.isExpired(token)) {
        print('⏰ Token JWT expirado (verificación cliente)');
        await TokenManager.clearAuthData();
        if (mounted) {
          TokenManager.showSessionExpiredMessage(context);
        }
        return;
      }

      // Verificar con el backend
      print('🔍 Verificando token con el backend...');
      final isValidInBackend = await _verifyTokenWithBackend(token);
      
      if (isValidInBackend) {
        print('✅ Token válido en backend, redirigiendo a inicio');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const InicioScreen()),
          );
        }
      } else {
        print('❌ Token rechazado por el backend');
        await TokenManager.clearAuthData();
        if (mounted) {
          TokenManager.showSessionExpiredMessage(context);
        }
      }
    } catch (e) {
      print('❌ Error verificando token: $e');
      await TokenManager.clearAuthData();
    }
  }

  // Verificar token con el backend
  Future<bool> _verifyTokenWithBackend(String token) async {
    try {
      final response = await http.get(
        Uri.parse("${confGlobal.baseUrl}/users/detail/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error verificando token con backend: $e');
      return false;
    }
  }

  // Solo limpiar tokens expirados sin redireccionar
  Future<void> _cleanExpiredTokenOnly() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      
      if (token != null && JwtDecoder.isExpired(token)) {
        print('⏰ Token JWT expirado, limpiando...');
        await TokenManager.clearAuthData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tu sesión anterior ha expirado.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error verificando token: $e');
      await TokenManager.clearAuthData();
    }
  }

  // Método para guardar el email del usuario (usando SharedPreferences)
  Future<void> _saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    print('✅ Email guardado en SharedPreferences: $email');
  }

  // Método para guardar el token de autenticación (clave cambiada a 'jwt_token')
  Future<void> _saveAuthToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token); // Clave consistente con chat.dart
    print('✅ Token JWT guardado correctamente en SecureStorage');
  }

  // Método para guardar el RUT del usuario (usando FlutterSecureStorage)
  Future<void> _saveUserRut(String rut) async {
    await _storage.write(key: 'user_rut', value: rut);
    print('✅ RUT de usuario guardado correctamente en SecureStorage: $rut');
  }

  Future<void> login() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    setState(() => cargando = true);

    try {
      final response = await http.post(
        Uri.parse("${confGlobal.baseUrl}/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      setState(() => cargando = false);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        print('🔑 Respuesta del login: $data');

        final String? token = data['data']?['token'];

        if (token != null) {
          // --- NUEVA LÓGICA: Decodificar el token para obtener el RUT ---
          try {
            Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
            final String? userRut = decodedToken['rut']; // Asumiendo que el RUT está en el payload del JWT

            if (userRut != null) {
              await _saveAuthToken(token); // Guardar el token
              await _saveUserRut(userRut); // Guardar el RUT decodificado
              await _saveUserEmail(email); // Guardar el email (si lo sigues necesitando en SharedPreferences)

              print('✅ Login exitoso. Token y RUT ($userRut) guardados.');

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const InicioScreen()),
              );
            } else {
              print('⚠️ RUT no encontrado en el payload del token JWT.');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("❌ Error de login: RUT no encontrado en el token.")),
              );
            }
          } catch (e) {
            print('❌ Error al decodificar el token JWT: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("❌ Error de login: Token JWT inválido. $e")),
            );
          }
        } else {
          print('⚠️ No se encontró token en la respuesta del login. Estructura de data: ${data['data']}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Error en la respuesta del servidor: Token no encontrado.")),
          );
        }
      } else {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final error = data["error"] ?? data["message"] ?? response.body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ $error")),
        );
      }
    } catch (e) {
      setState(() => cargando = false);
      print('❌ Error de red o parseo durante el login: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error de conexión: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Tu método build() permanece sin cambios) ...
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/icon/background.png',
            fit: BoxFit.cover,
          ),
          Container(
            color: const Color.fromARGB(128, 0, 0, 0)
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icon/logosf.png',
                    height: 240,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Iniciar sesión",
                    style: TextStyle(color: Colors.white70, fontSize: 20),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Correo electrónico",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: !verClave,
                    decoration: InputDecoration(
                      labelText: "Contraseña",
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          verClave ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            verClave = !verClave;
                          });
                        },
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: cargando ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(150, 81, 52, 23),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: cargando
                        ? const CircularProgressIndicator(color: Colors.white70)
                        : const Text("Siguiente"),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VerificarCorreoPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "Crear cuenta",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecuperarContrasenaPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "¿Olvidaste tu contraseña?",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}