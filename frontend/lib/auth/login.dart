import 'package:flutter/material.dart';
import 'verificacion.dart';
import '../mapa.dart';
import './recuperacion.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  Future<void> login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    setState(() => cargando = true);

    final response = await http.post(
      Uri.parse("http://10.0.2.2:3000/api/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    setState(() => cargando = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Login exitoso")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MapPage()),
      );
    } else {
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
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Iniciar sesión",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 24),
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
                        verClave
                            ? Icons.visibility
                            : Icons.visibility_off,
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
                  backgroundColor: Colors.blue[700],
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: cargando
                    ? const CircularProgressIndicator(color: Colors.white)
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
    );
  }
}