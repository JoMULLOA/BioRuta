import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/token_manager.dart';
import '../config/confGlobal.dart';

class EditarVehiculoPage extends StatefulWidget {
  final Map<String, dynamic> vehiculo;

  const EditarVehiculoPage({super.key, required this.vehiculo});

  @override
  State<EditarVehiculoPage> createState() => _EditarVehiculoPageState();
}

class _EditarVehiculoPageState extends State<EditarVehiculoPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores
  late TextEditingController _patenteController;
  late TextEditingController _marcaController;
  late TextEditingController _modeloController;
  late TextEditingController _anoController;
  late TextEditingController _colorController;
  late TextEditingController _nroAsientosController;
  late TextEditingController _documentacionController;
  
  String? _tipoSeleccionado;
  String? _combustibleSeleccionado;
  bool _isLoading = false;

  final List<String> _tiposVehiculo = [
    'sedan',
    'hatchback',
    'suv',
    'pickup',
    'furgon',
    'camioneta',
    'coupe',
    'convertible',
    'otro'
  ];

  final List<String> _tiposCombustible = [
    'bencina',
    'petroleo',
    'electrico',
    'hibrido',
    'gas'
  ];

  String _getNombreTipo(String tipo) {
    switch (tipo) {
      case 'sedan':
        return 'Sedán';
      case 'hatchback':
        return 'Hatchback';
      case 'suv':
        return 'SUV';
      case 'pickup':
        return 'Pickup';
      case 'furgon':
        return 'Furgón';
      case 'camioneta':
        return 'Camioneta';
      case 'coupe':
        return 'Coupé';
      case 'convertible':
        return 'Convertible';
      case 'otro':
        return 'Otro';
      default:
        return tipo;
    }
  }

  String _getNombreCombustible(String tipoCombustible) {
    switch (tipoCombustible) {
      case 'bencina':
        return 'Bencina';
      case 'petroleo':
        return 'Petróleo (Diésel)';
      case 'electrico':
        return 'Eléctrico';
      case 'hibrido':
        return 'Híbrido';
      case 'gas':
        return 'Gas';
      default:
        return tipoCombustible;
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Debug: Imprimir los datos del vehículo
    print('DEBUG EditarVehiculo - Datos recibidos: ${widget.vehiculo}');
    
    // Inicializar controladores con los datos actuales del vehículo
    _patenteController = TextEditingController(text: widget.vehiculo['patente'] ?? '');
    
    // Validar que el tipo del vehículo esté en la lista válida
    String tipoActual = widget.vehiculo['tipo'] ?? 'otro';
    _tipoSeleccionado = _tiposVehiculo.contains(tipoActual) ? tipoActual : 'otro';
    
    // Validar que el tipo de combustible esté en la lista válida
    String combustibleActual = widget.vehiculo['tipoCombustible'] ?? 'bencina';
    _combustibleSeleccionado = _tiposCombustible.contains(combustibleActual) ? combustibleActual : 'bencina';
    
    print('DEBUG EditarVehiculo - Tipo actual: $tipoActual, Tipo seleccionado: $_tipoSeleccionado');
    print('DEBUG EditarVehiculo - Combustible actual: $combustibleActual, Combustible seleccionado: $_combustibleSeleccionado');
    
    _marcaController = TextEditingController(text: widget.vehiculo['marca'] ?? '');
    _modeloController = TextEditingController(text: widget.vehiculo['modelo'] ?? '');
    _anoController = TextEditingController(text: (widget.vehiculo['año'] ?? widget.vehiculo['ano'] ?? '').toString());
    _colorController = TextEditingController(text: widget.vehiculo['color'] ?? '');
    _nroAsientosController = TextEditingController(text: (widget.vehiculo['nro_asientos'] ?? '').toString());
    _documentacionController = TextEditingController(text: widget.vehiculo['documentacion'] ?? '');
  }

  @override
  void dispose() {
    _patenteController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anoController.dispose();
    _colorController.dispose();
    _nroAsientosController.dispose();
    _documentacionController.dispose();
    super.dispose();
  }

  Future<void> _actualizarVehiculo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        _showErrorDialog('No se pudo obtener token de autenticación');
        return;
      }

      // Añadir Content-Type para JSON
      headers['Content-Type'] = 'application/json';

      final body = {
        'tipo': _tipoSeleccionado ?? 'otro',
        'marca': _marcaController.text.trim(),
        'modelo': _modeloController.text.trim(),
        'año': int.tryParse(_anoController.text.trim()) ?? 0,
        'color': _colorController.text.trim(),
        'nro_asientos': int.tryParse(_nroAsientosController.text.trim()) ?? 0,
        'tipoCombustible': _combustibleSeleccionado ?? 'bencina',
        'documentacion': _documentacionController.text.trim(),
      };

      final response = await http.patch(
        Uri.parse('${confGlobal.baseUrl}/vehiculos/${widget.vehiculo['patente']}'),
        headers: headers,
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vehículo actualizado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Retornar true para indicar que se actualizó
        }
      } else {
        _showErrorDialog(data['message'] ?? 'Error al actualizar vehículo');
      }
    } catch (e) {
      _showErrorDialog('Error de conexión: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
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
        title: Text('Editar Vehículo', style: TextStyle(color: primario)),
        iconTheme: IconThemeData(color: primario),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primario),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información de la patente (no editable)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primario.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.info, color: primario, size: 24),
                          SizedBox(height: 8),
                          Text(
                            'Patente: ${widget.vehiculo['patente']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primario,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'La patente no se puede modificar',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Formulario de edición
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información del Vehículo',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primario,
                            ),
                          ),
                          
                          SizedBox(height: 20),
                          
                          // Dropdown para tipo de vehículo
                          DropdownButtonFormField<String>(
                            value: _tiposVehiculo.contains(_tipoSeleccionado) ? _tipoSeleccionado : null,
                            hint: Text('Selecciona el tipo de vehículo'),
                            decoration: InputDecoration(
                              labelText: 'Tipo de Vehículo',
                              prefixIcon: Icon(Icons.category, color: primario),
                              labelStyle: TextStyle(color: primario),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: primario.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: primario, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            items: _tiposVehiculo.map((String tipo) {
                              return DropdownMenuItem<String>(
                                value: tipo,
                                child: Text(_getNombreTipo(tipo)),
                              );
                            }).toList(),
                            onChanged: (String? nuevoTipo) {
                              setState(() {
                                _tipoSeleccionado = nuevoTipo;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Selecciona un tipo de vehículo';
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Dropdown para tipo de combustible
                          DropdownButtonFormField<String>(
                            value: _tiposCombustible.contains(_combustibleSeleccionado) ? _combustibleSeleccionado : null,
                            hint: Text('Selecciona el tipo de combustible'),
                            decoration: InputDecoration(
                              labelText: 'Tipo de Combustible',
                              prefixIcon: Icon(Icons.local_gas_station, color: primario),
                              labelStyle: TextStyle(color: primario),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: primario.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: primario, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            items: _tiposCombustible.map((String tipo) {
                              return DropdownMenuItem<String>(
                                value: tipo,
                                child: Text(_getNombreCombustible(tipo)),
                              );
                            }).toList(),
                            onChanged: (String? nuevoTipo) {
                              setState(() {
                                _combustibleSeleccionado = nuevoTipo;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Selecciona un tipo de combustible';
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Campo Marca
                          _buildFormField(
                            controller: _marcaController,
                            label: 'Marca',
                            icon: Icons.branding_watermark,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'La marca es obligatoria';
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Campo Modelo
                          _buildFormField(
                            controller: _modeloController,
                            label: 'Modelo',
                            icon: Icons.directions_car,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El modelo es obligatorio';
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Campo Año
                          _buildFormField(
                            controller: _anoController,
                            label: 'Año',
                            icon: Icons.calendar_today,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El año es obligatorio';
                              }
                              final ano = int.tryParse(value);
                              final currentYear = DateTime.now().year;
                              if (ano == null || ano < 1990 || ano > currentYear + 1) {
                                return 'Ingresa un año válido (1990-${currentYear + 1})';
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Campo Color
                          _buildFormField(
                            controller: _colorController,
                            label: 'Color',
                            icon: Icons.palette,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El color es obligatorio';
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Campo Número de Asientos
                          _buildFormField(
                            controller: _nroAsientosController,
                            label: 'Número de Asientos',
                            icon: Icons.people,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El número de asientos es obligatorio';
                              }
                              final numero = int.tryParse(value.trim());
                              if (numero == null || numero < 1 || numero > 8) {
                                return 'Debe ser un número entre 1 y 8';
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Campo Documentación
                          _buildFormField(
                            controller: _documentacionController,
                            label: 'Documentación',
                            icon: Icons.description,
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'La documentación es obligatoria';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Botón de actualizar
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _actualizarVehiculo,
                        icon: Icon(Icons.save, color: Colors.white),
                        label: Text(
                          'Guardar Cambios',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primario,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final Color primario = Color(0xFF6B3B2D);
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primario),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        labelStyle: TextStyle(color: primario),
      ),
    );
  }
}
