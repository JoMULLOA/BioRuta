import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/token_manager.dart';
import '../config/confGlobal.dart';

class AgregarVehiculoPage extends StatefulWidget {
  const AgregarVehiculoPage({super.key});

  @override
  State<AgregarVehiculoPage> createState() => _AgregarVehiculoPageState();
}

class _AgregarVehiculoPageState extends State<AgregarVehiculoPage> {
  final _formKey = GlobalKey<FormState>();
  final _patenteController = TextEditingController();
  final _modeloController = TextEditingController();
  final _colorController = TextEditingController();
  final _asientosController = TextEditingController();
  final _documentacionController = TextEditingController();
  
  bool _isSaving = false;

  @override
  void dispose() {
    _patenteController.dispose();
    _modeloController.dispose();
    _colorController.dispose();
    _asientosController.dispose();
    _documentacionController.dispose();
    super.dispose();
  }

  Future<void> _saveVehiculo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        _showError('No se pudo obtener token de autenticación');
        setState(() {
          _isSaving = false;
        });
        return;
      }

      // Preparar datos del vehículo
      final vehiculoData = {
        'patente': _patenteController.text.toUpperCase(),
        'modelo': _modeloController.text,
        'color': _colorController.text,
        'nro_asientos': int.parse(_asientosController.text),
        'documentacion': _documentacionController.text,
      };

      print('🚗 Enviando datos del vehículo: $vehiculoData');

      final response = await http.post(
        Uri.parse('${confGlobal.baseUrl}/vehiculos/crear'),
        headers: headers,
        body: json.encode(vehiculoData),
      );

      setState(() {
        _isSaving = false;
      });

      print('📄 Respuesta del servidor: ${response.statusCode}');
      print('📄 Cuerpo: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Vehículo agregado exitosamente'),
              ],
            ),
            backgroundColor: Colors.green[600],
          ),
        );
        
        Navigator.pop(context, true); // Regresar con indicador de éxito
      } else {
        try {
          final errorData = json.decode(response.body);
          _showError(errorData['message'] ?? 'Error al agregar vehículo');
        } catch (e) {
          _showError('Error al agregar vehículo (${response.statusCode})');
        }
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      _showError('Error de conexión: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color fondo = Color(0xFFF8F2EF);
    final Color primario = Color(0xFF6B3B2D);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: fondo,
        elevation: 0,
        title: Text('Agregar Vehículo', style: TextStyle(color: primario)),
        iconTheme: IconThemeData(color: primario),
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: _saveVehiculo,
              child: Text(
                'Guardar',
                style: TextStyle(
                  color: primario,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información del Vehículo
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información del Vehículo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primario,
                      ),
                    ),
                    SizedBox(height: 20),
                    
                    _buildTextField(
                      controller: _patenteController,
                      label: 'Patente',
                      icon: Icons.confirmation_number,
                      hint: 'XXXX11 o XX1111',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'La patente es obligatoria';
                        }
                        // Validar formato de patente chilena
                        if (!RegExp(r'^[A-Z]{2}\d{4}$|^[A-Z]{4}\d{2}$').hasMatch(value.toUpperCase())) {
                          return 'Formato de patente inválido (ej: AB1234 o ABCD12)';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        // Convertir a mayúsculas automáticamente
                        final cursorPos = _patenteController.selection;
                        _patenteController.value = _patenteController.value.copyWith(
                          text: value.toUpperCase(),
                          selection: cursorPos,
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _modeloController,
                      label: 'Modelo',
                      icon: Icons.directions_car,
                      hint: 'Ej: Toyota Corolla 2020',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El modelo es obligatorio';
                        }
                        if (value.length < 3) {
                          return 'El modelo debe tener al menos 3 caracteres';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _colorController,
                      label: 'Color',
                      icon: Icons.palette,
                      hint: 'Ej: Blanco, Negro, Rojo',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El color es obligatorio';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _asientosController,
                      label: 'Número de Asientos',
                      icon: Icons.people,
                      hint: 'Ej: 4, 5, 7',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El número de asientos es obligatorio';
                        }
                        final asientos = int.tryParse(value);
                        if (asientos == null || asientos < 2 || asientos > 9) {
                          return 'Debe ser un número entre 2 y 9';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _documentacionController,
                      label: 'Documentación',
                      icon: Icons.description,
                      hint: 'Ej: Revisión técnica al día, seguro vigente',
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'La documentación es obligatoria';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Botón de Guardar
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveVehiculo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primario,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Agregar Vehículo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    final Color primario = Color(0xFF6B3B2D);
    final Color secundario = Color(0xFF8D4F3A);

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primario),
        labelStyle: TextStyle(color: primario),
        hintStyle: TextStyle(color: Colors.grey[400]),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: secundario.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
