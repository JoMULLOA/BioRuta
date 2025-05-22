import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegistroPage extends StatefulWidget {
  final String email;

  const RegistroPage({super.key, required this.email});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final _nombreController = TextEditingController();
  final _rutController = TextEditingController();
  final _rolController = TextEditingController();
  final _passwordController = TextEditingController();
  bool cargando = false;

  Future<void> registrarUsuario() async {
    setState(() => cargando = true);

    final response = await http.post(
      Uri.parse("http://10.0.2.2:3000/api/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "nombreCompleto": _nombreController.text.trim(),
        "rut": _rutController.text.trim(),
        "email": widget.email,
        "rol": _rolController.text.trim(),
        "password": _passwordController.text.trim(),
      }),
    );

    setState(() => cargando = false);

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🎉 Usuario registrado con éxito")),
      );
      Navigator.pushReplacementNamed(context, "/mapa");
    } else {
      final error = jsonDecode(response.body)["error"] ?? "Error desconocido";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $error")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Completa tu registro")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: "Nombre completo"),
            ),
            TextField(
              controller: _rutController,
              decoration: const InputDecoration(labelText: "RUT"),
            ),
            TextField(
              controller: _rolController,
              decoration: const InputDecoration(labelText: "Rol"),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Contraseña"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: cargando ? null : registrarUsuario,
              child: cargando
                  ? const CircularProgressIndicator()
                  : const Text("Registrar"),
            ),
          ],
        ),
      ),
    );
  }
}
