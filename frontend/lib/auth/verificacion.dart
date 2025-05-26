import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'registro.dart';

class VerificarCorreoPage extends StatefulWidget {
  const VerificarCorreoPage({super.key});

  @override
  State<VerificarCorreoPage> createState() => _VerificarCorreoPageState();
}

class _VerificarCorreoPageState extends State<VerificarCorreoPage> {
  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();
  bool codigoEnviado = false;
  bool cargando = false;

  Future<void> enviarCodigo() async {
    setState(() => cargando = true);

    final response = await http.post(
      Uri.parse("http://10.0.2.2:3000/api/auth/send-code"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": _emailController.text.trim().toLowerCase()}),
    );

    setState(() => cargando = false);

    if (response.statusCode == 200) {
      setState(() => codigoEnviado = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📧 Código enviado al correo")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al enviar código")),
      );
    }
  }

  Future<void> verificarCodigo() async {
    setState(() => cargando = true);

    final response = await http.post(
      Uri.parse("http://10.0.2.2:3000/api/auth/verify-code"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": _emailController.text.trim().toLowerCase(),
        "code": _codigoController.text.trim()
      }),
    );

    setState(() => cargando = false);

    if (response.statusCode == 200) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RegistroPage(email: _emailController.text.trim()),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Código inválido")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crear cuenta")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Correo electrónico"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            if (codigoEnviado)
              TextField(
                controller: _codigoController,
                decoration: const InputDecoration(labelText: "Código de verificación"),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: cargando
                  ? null
                  : codigoEnviado
                      ? verificarCodigo
                      : enviarCodigo,
              child: cargando
                  ? const CircularProgressIndicator()
                  : Text(codigoEnviado ? "Verificar código" : "Enviar código"),
            ),
          ],
        ),
      ),
    );
  }
}
