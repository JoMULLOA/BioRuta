import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PublicarPage extends StatefulWidget {
  @override
  _PublicarPageState createState() => _PublicarPageState();
}

class _PublicarPageState extends State<PublicarPage> {
  TextEditingController _ubicacionController = TextEditingController();
  List<dynamic> _resultados = [];
  String? _ubicacionSeleccionada;

  // Función para buscar la ubicación usando Nominatim
  Future<void> buscarUbicacion(String query) async {
    if (query.isEmpty) {
      setState(() {
        _resultados = [];
      });
      return;
    }
    final url =
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5';
    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'FlutterApp (tu_email@dominio.com)', // Nominatim pide User-Agent válido
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _resultados = data;
      });
    } else {
      setState(() {
        _resultados = [];
      });
    }
  }

  // Cuando el usuario selecciona una ubicación
  void seleccionarUbicacion(dynamic lugar) {
    setState(() {
      _ubicacionSeleccionada = lugar['display_name'];
      _resultados = [];
      _ubicacionController.text = _ubicacionSeleccionada!;
    });
    FocusScope.of(context).unfocus(); // Ocultar teclado
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Publicar'),
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () {
              if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/inicio');
    }
        },
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿De dónde sales?', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          TextField(
            controller: _ubicacionController,
            decoration: InputDecoration(
              hintText: 'Ingresa tu ubicación de salida',
              border: OutlineInputBorder(),
              suffixIcon: _ubicacionController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _ubicacionController.clear();
                          _resultados = [];
                          _ubicacionSeleccionada = null;
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              buscarUbicacion(value);
            },
          ),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _resultados.length,
              itemBuilder: (context, index) {
                final lugar = _resultados[index];
                return ListTile(
                  title: Text(lugar['display_name']),
                  onTap: () => seleccionarUbicacion(lugar),
                );
              },
            ),
          ),
          if (_ubicacionSeleccionada != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Ubicación seleccionada:\n$_ubicacionSeleccionada',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    ),
  );
}
}