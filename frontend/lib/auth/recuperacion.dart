import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'contrasena.dart';
import '../config/confGlobal.dart';

class RecuperarContrasenaPage extends StatefulWidget {
  const RecuperarContrasenaPage({super.key});

  @override
  State<RecuperarContrasenaPage> createState() => _RecuperarContrasenaPageState();
}

class _RecuperarContrasenaPageState extends State<RecuperarContrasenaPage> {
  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();
  bool codigoEnviado = false;
  bool cargando = false;

  Future<void> enviarCodigo() async {
    setState(() => cargando = true);

    final response = await http.post(
      Uri.parse("${confGlobal.baseUrl}/auth/send-coder"),
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
       Uri.parse("${confGlobal.baseUrl}/auth/verify-code"),
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
          builder: (_) => CambiarContrasenaPage(email: _emailController.text.trim()),
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
                  "Recuperar contraseña",
                  style: TextStyle(color: Colors.white, fontSize: 25),
                ),
              const SizedBox(height: 40),
              const Text(
                "Ingresa tu correo",
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
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
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              if (codigoEnviado)
                TextField(
                  controller: _codigoController,
                  decoration: const InputDecoration(
                    labelText: "Código de recuperación",
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: cargando
                    ? null
                    : codigoEnviado
                        ? verificarCodigo
                        : enviarCodigo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(150, 81, 52, 23),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: cargando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        codigoEnviado ? "Verificar código" : "Enviar código",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}
