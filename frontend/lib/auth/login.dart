import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'verificacion.dart';
import '../buscar/inicio.dart';
import './recuperacion.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/confGlobal.dart';

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

  // Método para guardar el email del usuario
  Future<void> _saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
  }

  // Método para guardar el token de autenticación
  Future<void> _saveAuthToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
    print('✅ Token guardado correctamente');
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

    final response = await http.post(
      Uri.parse("${confGlobal.baseUrl}/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );    
    setState(() => cargando = false);    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      // Extraer el token de la respuesta
      final String? token = data['data']?['token'];
      print ('🔑 Token recibido: $token');
      if (token != null) {
        // Guardar el token de autenticación
        await _saveAuthToken(token);
        print('✅ Token guardado: ${token.substring(0, 20)}...');
      } else {
        print('⚠️ No se encontró token en la respuesta');
        print('📋 Estructura de data: ${data['data']}');
      }
      // Guardar el email del usuario en SharedPreferences
      await _saveUserEmail(email);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const InicioScreen()),
      );
    } else {
      print ('❌ Error al iniciar sesión: ${response.statusCode}');
      print ('📋 Respuesta: ${response.body}');
      final Map<String, dynamic> data = jsonDecode(response.body);
      final error = data["error"] ?? data["message"] ?? response.body;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $error")),
      );
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        // Imagen de fondo
        Image.asset(
          'assets/icon/background.png',
          fit: BoxFit.cover,
        ),

        // Capa de oscurecimiento opcional (mejora legibilidad)
        Container(
          color: const Color.fromARGB(128, 0, 0, 0)
        ),

        // Contenido del login
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