import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CambiarContrasenaPage extends StatefulWidget {
  final String email;

  const CambiarContrasenaPage({super.key, required this.email});

  @override
  State<CambiarContrasenaPage> createState() => _CambiarContrasenaPageState();
}

class _CambiarContrasenaPageState extends State<CambiarContrasenaPage> {
  final _passwordController = TextEditingController();
  bool cargando = false;
  bool verClave = false;

  Future<void> actualizarUsuario() async {
    setState(() => cargando = true);

    final response = await http.post(
      Uri.parse("http://10.0.2.2:3000/api/user/actualizar?email=${widget.email.toLowerCase()}"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "password": _passwordController.text.trim(),
      }),
    );

    setState(() => cargando = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🎉 Contraseña cambiada con éxito")),
      );
      Navigator.pushReplacementNamed(context, "/login");
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
      appBar: AppBar(title: const Text("Completa tu contraseña")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: cargando ? null : actualizarUsuario,
              child: cargando
                  ? const CircularProgressIndicator()
                  : const Text("Cambiar contraseña"),
            ),
          ],
        ),
      ),
    );
  }
}