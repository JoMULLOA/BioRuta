import 'package:flutter/material.dart';
import 'registro.dart';

class VerificacionPage extends StatefulWidget {
  const VerificacionPage({super.key});

  @override
  State<VerificacionPage> createState() => _VerificacionPageState();
}

class _VerificacionPageState extends State<VerificacionPage> {
  final TextEditingController _emailController = TextEditingController();
  bool cargando = false;

  Future<void> simularVerificacion() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingrese un correo válido")),
      );
      return;
    }

    setState(() => cargando = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulación
    setState(() => cargando = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RegistroPage(email: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verificación de correo")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Correo institucional"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: cargando ? null : simularVerificacion,
              child: cargando
                  ? const CircularProgressIndicator()
                  : const Text("Verificar y continuar"),
            )
          ],
        ),
      ),
    );
  }
}