import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/token_manager.dart';
import '../config/confGlobal.dart';

class EditarPerfilPage extends StatefulWidget {
  const EditarPerfilPage({super.key});

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para los campos
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _carreraController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _fechaNacimientoController = TextEditingController();
  
  String? _generoSeleccionado;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  
  // Datos originales para comparar cambios
  Map<String, dynamic> _originalData = {};

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    _carreraController.dispose();
    _descripcionController.dispose();
    _fechaNacimientoController.dispose();
    super.dispose();
  }

  // Cargar datos actuales del usuario
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      
      if (email == null) {
        _showError('No se encontró información del usuario');
        return;
      }

      // Obtener headers de autenticación
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        _showError('Error de autenticación');
        return;
      }

      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/user/busqueda?email=$email'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          final userData = data['data'];
          _originalData = Map<String, dynamic>.from(userData);
          
          setState(() {
            _nombreController.text = userData['nombreCompleto'] ?? '';
            _emailController.text = userData['email'] ?? '';
            _carreraController.text = userData['carrera'] ?? '';
            _descripcionController.text = userData['descripcion'] ?? '';
            _generoSeleccionado = userData['genero'];
            
            // Formatear fecha de nacimiento para mostrar
            if (userData['fechaNacimiento'] != null) {
              try {
                final fecha = DateTime.parse(userData['fechaNacimiento']);
                _fechaNacimientoController.text = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
              } catch (e) {
                _fechaNacimientoController.text = '';
              }
            } else {
              _fechaNacimientoController.text = '';
            }
            
            _isLoading = false;
          });
        } else {
          _showError('Error en la respuesta del servidor');
        }
      } else {
        _showError('Error al cargar datos del usuario');
      }
    } catch (e) {
      _showError('Error de conexión: $e');
    }
  }

  // Guardar cambios
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Preparar datos a enviar (solo los campos que cambiaron)
      Map<String, dynamic> updateData = {};
      
      if (_nombreController.text != _originalData['nombreCompleto']) {
        updateData['nombreCompleto'] = _nombreController.text;
      }
      
      if (_carreraController.text != _originalData['carrera']) {
        updateData['carrera'] = _carreraController.text;
      }
      
      if (_descripcionController.text != _originalData['descripcion']) {
        updateData['descripcion'] = _descripcionController.text;
      }

      // Verificar cambios en género
      if (_generoSeleccionado != _originalData['genero']) {
        updateData['genero'] = _generoSeleccionado;
      }

      // Validar y agregar fecha de nacimiento si cambió
      if (_fechaNacimientoController.text.isNotEmpty) {
        try {
          // Convertir formato DD/MM/YYYY a YYYY-MM-DD para el backend
          final parts = _fechaNacimientoController.text.split('/');
          if (parts.length == 3) {
            final fechaFormatted = '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
            
            // Comparar con el original
            String originalFecha = '';
            if (_originalData['fechaNacimiento'] != null) {
              final fecha = DateTime.parse(_originalData['fechaNacimiento']);
              originalFecha = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
            }
            
            if (_fechaNacimientoController.text != originalFecha) {
              updateData['fechaNacimiento'] = fechaFormatted;
            }
          }
        } catch (e) {
          _showError('Formato de fecha inválido. Use DD/MM/YYYY');
          setState(() {
            _isSaving = false;
          });
          return;
        }
      } else {
        // Si el campo está vacío pero había fecha antes, eliminarla
        if (_originalData['fechaNacimiento'] != null) {
          updateData['fechaNacimiento'] = null;
        }
      }

      // Si se proporcionó contraseña actual, incluir cambio de contraseña
      if (_passwordController.text.isNotEmpty) {
        if (_newPasswordController.text.isEmpty) {
          _showError('Debe proporcionar una nueva contraseña');
          setState(() {
            _isSaving = false;
          });
          return;
        }
        updateData['password'] = _passwordController.text;
        updateData['newPassword'] = _newPasswordController.text;
      }

      if (updateData.isEmpty) {
        _showError('No hay cambios para guardar');
        setState(() {
          _isSaving = false;
        });
        return;
      }

      print('📤 Enviando datos de actualización: $updateData');

      // Obtener headers de autenticación
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        _showError('No se pudo obtener token de autenticación');
        setState(() {
          _isSaving = false;
        });
        return;
      }

      print('🔑 Headers obtenidos correctamente');
      print('🌐 URL: ${confGlobal.baseUrl}/user/actualizar?email=${_emailController.text}');

      // Hacer petición de actualización
      final response = await http.patch(
        Uri.parse('${confGlobal.baseUrl}/user/actualizar?email=${_emailController.text}'),
        headers: headers,
        body: json.encode(updateData),
      );

      setState(() {
        _isSaving = false;
      });

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Perfil actualizado exitosamente'),
              ],
            ),
            backgroundColor: Colors.green[600],
          ),
        );

        // Actualizar datos originales y limpiar campos de contraseña
        _originalData = Map<String, dynamic>.from(responseData['data']);
        _passwordController.clear();
        _newPasswordController.clear();
        
        Navigator.pop(context, true); // Regresar con indicador de actualización
      } else {
        print('❌ Error en respuesta del servidor: ${response.statusCode}');
        print('📄 Cuerpo de respuesta: ${response.body}');
        
        try {
          final errorData = json.decode(response.body);
          _showError(errorData['message'] ?? 'Error al actualizar perfil');
        } catch (e) {
          _showError('Error al actualizar perfil (${response.statusCode})');
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
    final Color secundario = Color(0xFF8D4F3A);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: fondo,
        elevation: 0,
        title: Text('Editar Perfil', style: TextStyle(color: primario)),
        iconTheme: IconThemeData(color: primario),
        actions: [
          if (!_isLoading && !_isSaving)
            TextButton(
              onPressed: _saveChanges,
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
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primario),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información Personal
                    _buildSectionCard(
                      'Información Personal',
                      [
                        _buildTextField(
                          controller: _nombreController,
                          label: 'Nombre Completo',
                          icon: Icons.person,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El nombre es obligatorio';
                            }
                            if (value.length < 10) {
                              return 'El nombre debe tener al menos 10 caracteres';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          enabled: false, // Email no se puede cambiar
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          controller: _carreraController,
                          label: 'Carrera',
                          icon: Icons.school,
                        ),
                        SizedBox(height: 16),
                        _buildGenderDropdown(),
                        SizedBox(height: 16),
                        _buildDateField(
                          controller: _fechaNacimientoController,
                          label: 'Fecha de Nacimiento',
                          icon: Icons.cake,
                          hint: 'DD/MM/YYYY',
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          controller: _descripcionController,
                          label: 'Descripción',
                          icon: Icons.description,
                          maxLines: 3,
                          hint: 'Cuéntanos un poco sobre ti...',
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Cambio de Contraseña
                    _buildSectionCard(
                      'Cambiar Contraseña',
                      [
                        Text(
                          'Deja estos campos vacíos si no quieres cambiar tu contraseña',
                          style: TextStyle(
                            color: secundario,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Contraseña Actual',
                          icon: Icons.lock_outline,
                          obscureText: _obscureCurrentPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                              color: secundario,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureCurrentPassword = !_obscureCurrentPassword;
                              });
                            },
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          controller: _newPasswordController,
                          label: 'Nueva Contraseña',
                          icon: Icons.lock,
                          obscureText: _obscureNewPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                              color: secundario,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (_passwordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                              return 'Debe proporcionar una nueva contraseña';
                            }
                            if (value != null && value.isNotEmpty && value.length < 8) {
                              return 'La nueva contraseña debe tener al menos 8 caracteres';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: 32),

                    // Botón de Guardar
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
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
                                'Guardar Cambios',
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

  Widget _buildSectionCard(String title, List<Widget> children) {
    final Color primario = Color(0xFF6B3B2D);
    
    return Container(
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
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primario,
            ),
          ),
          SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    bool enabled = true,
    int maxLines = 1,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final Color primario = Color(0xFF6B3B2D);
    final Color secundario = Color(0xFF8D4F3A);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: enabled ? primario : Colors.grey),
        suffixIcon: suffixIcon,
        labelStyle: TextStyle(color: enabled ? primario : Colors.grey),
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: true,
        fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    final Color primario = Color(0xFF6B3B2D);
    final Color secundario = Color(0xFF8D4F3A);

    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        // Parseae la fecha actual del controlador si existe
        DateTime? initialDate;
        if (controller.text.isNotEmpty) {
          try {
            final parts = controller.text.split('/');
            if (parts.length == 3) {
              initialDate = DateTime(
                int.parse(parts[2]), 
                int.parse(parts[1]), 
                int.parse(parts[0])
              );
            }
          } catch (e) {
            // Si hay error, usar fecha por defecto
          }
        }
        
        // Si no hay fecha inicial, usar hace 20 años
        initialDate ??= DateTime(DateTime.now().year - 20);
        
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: primario,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: primario,
                ),
              ),
              child: child!,
            );
          },
        );
        
        if (picked != null) {
          controller.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        }
      },
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          try {
            final parts = value.split('/');
            if (parts.length != 3) {
              return 'Formato de fecha inválido (DD/MM/YYYY)';
            }
            
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            
            if (day < 1 || day > 31) return 'Día inválido';
            if (month < 1 || month > 12) return 'Mes inválido';
            if (year < 1950 || year > DateTime.now().year) return 'Año inválido';
            
            final fecha = DateTime(year, month, day);
            if (fecha.isAfter(DateTime.now())) {
              return 'La fecha no puede ser en el futuro';
            }
          } catch (e) {
            return 'Formato de fecha inválido';
          }
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primario),
        suffixIcon: Icon(Icons.calendar_today, color: secundario),
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

  Widget _buildGenderDropdown() {
    final Color primario = Color(0xFF6B3B2D);
    final Color secundario = Color(0xFF8D4F3A);

    return DropdownButtonFormField<String>(
      value: _generoSeleccionado,
      hint: Text('Selecciona tu género'),
      decoration: InputDecoration(
        labelText: 'Género',
        prefixIcon: Icon(Icons.person_outline, color: primario),
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
      items: _opcionesGenero.map((String genero) {
        return DropdownMenuItem<String>(
          value: genero,
          child: Text(_getNombreGenero(genero)),
        );
      }).toList(),
      onChanged: (String? nuevoGenero) {
        setState(() {
          _generoSeleccionado = nuevoGenero;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Selecciona un género';
        }
        return null;
      },
    );
  }
}
