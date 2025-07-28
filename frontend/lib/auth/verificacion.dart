import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './registro.dart';
import '../config/confGlobal.dart';

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
      Uri.parse("${confGlobal.baseUrl}/auth/send-code"),
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
      final Map<String, dynamic> data = jsonDecode(response.body);
      
      // Mejorar el manejo de errores para mostrar mensajes específicos de validación
      String errorMessage = "Error al enviar código";
      
      // 1. PRIMERO verificar si hay detalles específicos de validación
      if (data.containsKey("details") && data["details"] != null) {
        errorMessage = data["details"].toString();
      }
      // 2. Verificar si hay un mensaje directo
      else if (data.containsKey("message") && data["message"] != null) {
        errorMessage = data["message"];
      }
      // 3. Verificar si hay un error general 
      else if (data.containsKey("error") && data["error"] != null) {
        var errorData = data["error"];
        
        if (errorData is String) {
          errorMessage = errorData;
        } else if (errorData is Map && errorData.containsKey("message")) {
          errorMessage = errorData["message"];
        }
      }
      
      print('❌ Error enviando código: $errorMessage');
      print('📄 Estructura completa del error: $data');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ $errorMessage"),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red,
        ),
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
          builder: (_) => RegistroPage(email: _emailController.text.trim()),
        ),
      );
    } else {
      final Map<String, dynamic> data = jsonDecode(response.body);
      
      // Mejorar el manejo de errores para mostrar mensajes específicos
      String errorMessage = "Código inválido";
      
      // 1. PRIMERO verificar si hay detalles específicos de validación
      if (data.containsKey("details") && data["details"] != null) {
        errorMessage = data["details"].toString();
      }
      // 2. Verificar si hay un mensaje directo
      else if (data.containsKey("message") && data["message"] != null) {
        errorMessage = data["message"];
      }
      // 3. Verificar si hay un error general 
      else if (data.containsKey("error") && data["error"] != null) {
        var errorData = data["error"];
        
        if (errorData is String) {
          errorMessage = errorData;
        } else if (errorData is Map && errorData.containsKey("message")) {
          errorMessage = errorData["message"];
        }
      }
      
      print('❌ Error verificando código: $errorMessage');
      print('📄 Estructura completa del error: $data');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ $errorMessage"),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red,
        ),
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
                "Verifica tu correo",
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
                    labelText: "Código de verificación",
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
