import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './login.dart';

class RegistroPage extends StatefulWidget {
  final String email;

  const RegistroPage({super.key, required this.email});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final _nombreController = TextEditingController();
  final _rutController = TextEditingController();
  final _carreraController = TextEditingController();
  final _passwordController = TextEditingController();
  bool cargando = false;
  bool verClave = false;

  Future<void> registrarUsuario() async {
    setState(() => cargando = true);

    final response = await http.post(
      Uri.parse("http://146.83.198.35:1245/api/auth/register"),
      //Uri.parse("http://10.0.2.2:3000/api/auth/register"),
      //Uri.parse("http://localhost:3000/api/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "nombreCompleto": _nombreController.text.trim(),
        "rut": _rutController.text.trim().toUpperCase(),
        "email": widget.email.toLowerCase(),
        "carrera": _carreraController.text.trim(),
        "rol": "pasajero",
        "password": _passwordController.text.trim(),
      }),
    );

    setState(() => cargando = false);

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🎉 Usuario registrado con éxito")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen de fondo
          Image.asset(
            'assets/icon/background.png',
            fit: BoxFit.cover,
          ),

          // Capa de oscurecimiento para mejorar contraste
          Container(
            color: const Color.fromARGB(128, 0, 0, 0)
          ),

          // Contenido encima del fondo
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 100),
                const Text(
                    "Crear cuenta",
                    style: TextStyle(color: Colors.white, fontSize: 25),
                  ),
                const SizedBox(height: 40),
                const Text(
                  "Completa tu registro",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: "Nombre completo"),
                ),
                TextField(
                  controller: _rutController,
                  decoration: const InputDecoration(labelText: "RUT"),
                ),
                TextField(
                  controller: _carreraController,
                  decoration: const InputDecoration(labelText: "Carrera"),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: !verClave,
                  decoration: InputDecoration(
                    labelText: "Contraseña nueva",
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
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: cargando ? null : registrarUsuario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(150, 81, 52, 23), // Fondo café opaco
                    foregroundColor: Colors.white, // Texto y spinner blanco
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: cargando
                      ? const CircularProgressIndicator()
                      : const Text("Registrar"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    }
  }