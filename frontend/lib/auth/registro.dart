import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './login.dart';
import '../config/confGlobal.dart';

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
  DateTime? _fechaNacimiento;
  String? _generoSeleccionado;
  bool cargando = false;
  bool verClave = false;

  final List<String> _opcionesGenero = [
    'masculino',
    'femenino', 
    'no_binario',
    'prefiero_no_decir'
  ];

  String _getNombreGenero(String genero) {
    switch (genero) {
      case 'masculino':
        return 'Masculino';
      case 'femenino':
        return 'Femenino';
      case 'no_binario':
        return 'No binario';
      case 'prefiero_no_decir':
        return 'Prefiero no decir';
      default:
        return genero;
    }
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && picked != _fechaNacimiento) {
      setState(() {
        _fechaNacimiento = picked;
      });
    }
  }

  Future<void> registrarUsuario() async {
    // Validaciones
    if (_fechaNacimiento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Selecciona tu fecha de nacimiento")),
      );
      return;
    }
    
    if (_generoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Selecciona tu género")),
      );
      return;
    }

    setState(() => cargando = true);

    // Formatear la fecha para el backend
    final fechaFormateada = "${_fechaNacimiento!.year}-${_fechaNacimiento!.month.toString().padLeft(2, '0')}-${_fechaNacimiento!.day.toString().padLeft(2, '0')}";

    final response = await http.post(
      Uri.parse("${confGlobal.baseUrl}/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "nombreCompleto": _nombreController.text.trim(),
        "rut": _rutController.text.trim().toUpperCase(),
        "email": widget.email.toLowerCase(),
        "carrera": _carreraController.text.trim(),
        "rol": "estudiante",
        "password": _passwordController.text.trim(),
        "fechaNacimiento": fechaFormateada,
        "genero": _generoSeleccionado,
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
      
      // Mejorar el manejo de errores para mostrar mensajes específicos de validación
      String errorMessage = "Error desconocido";
      
      // 1. PRIMERO verificar si hay detalles específicos de validación (aquí está el mensaje real)
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
        
        // Si el error es un objeto con mensaje específico
        if (errorData is Map && errorData.containsKey("message")) {
          errorMessage = errorData["message"];
        }
        // Si el error es un string directo
        else if (errorData is String) {
          errorMessage = errorData;
        }
        // Si el error tiene field (estructura del backend para registro)
        else if (errorData is Map && errorData.containsKey("field")) {
          String field = errorData["field"] ?? "";
          String msg = errorData["message"] ?? "";
          errorMessage = field.isEmpty ? msg : "$field: $msg";
        }
        // Si el error tiene dataInfo (estructura del backend para login)
        else if (errorData is Map && errorData.containsKey("dataInfo")) {
          String field = errorData["dataInfo"] ?? "";
          String msg = errorData["message"] ?? "";
          errorMessage = field.isEmpty ? msg : "$field: $msg";
        }
        else {
          errorMessage = errorData.toString();
        }
      }
      // 4. Fallback al cuerpo completo de la respuesta
      else {
        errorMessage = response.body;
      }
      
      print('❌ Error de registro: $errorMessage');
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
  void dispose() {
    _nombreController.dispose();
    _rutController.dispose();
    _carreraController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                  decoration: const InputDecoration(
                    labelText: "Nombre completo",
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rutController,
                  decoration: const InputDecoration(
                    labelText: "RUT",
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _carreraController,
                  decoration: const InputDecoration(
                    labelText: "Carrera",
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                
                // Campo de fecha de nacimiento
                GestureDetector(
                  onTap: _seleccionarFecha,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white70),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _fechaNacimiento == null
                              ? "Fecha de nacimiento"
                              : "${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}",
                          style: TextStyle(
                            color: _fechaNacimiento == null 
                                ? Colors.white70 
                                : Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Campo de género
                DropdownButtonFormField<String>(
                  value: _generoSeleccionado,
                  hint: const Text(
                    "Seleccionar género",
                    style: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color.fromARGB(200, 81, 52, 23),
                  decoration: const InputDecoration(
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: _opcionesGenero.map((String genero) {
                    return DropdownMenuItem<String>(
                      value: genero,
                      child: Text(
                        _getNombreGenero(genero),
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? nuevoValor) {
                    setState(() {
                      _generoSeleccionado = nuevoValor;
                    });
                  },
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