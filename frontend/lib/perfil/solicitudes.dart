import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/confGlobal.dart';
import '../services/amistad_service.dart';
import '../utils/token_manager.dart';
import '../helpers/notificacion_helpers.dart';

class Solicitud extends StatefulWidget {
  @override
  State<Solicitud> createState() => _SolicitudState();
}

class _SolicitudState extends State<Solicitud> {
  final TextEditingController _rutController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isValidRut = false;
  String _errorMessage = '';
  bool _isLoading = false;
  Map<String, dynamic>? _usuarioEncontrado;

  @override
  void initState() {
    super.initState();
    _rutController.addListener(_validateRut);
  }

  @override
  void dispose() {
    _rutController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _validateRut() {
    String rut = _rutController.text.replaceAll(RegExp(r'[^0-9kK]'), '');
    
    print('RUT validando: "$rut" - Longitud: ${rut.length}');
    setState(() {
      if (rut.isEmpty) {
        _isValidRut = false;
        _errorMessage = '';
      } else if (rut.length < 8) {
        _isValidRut = false;
        _errorMessage = 'RUT debe tener al menos 8 caracteres';
      } else if (rut.length > 9) {
        _isValidRut = false;
        _errorMessage = 'RUT demasiado largo';
      } else {
        _isValidRut = true;
        _errorMessage = '';
      }
    });
    print('¿Es válido? $_isValidRut');
  }

  String _formatRut(String value) {
    // Remover todo excepto números y K
    String cleanRut = value.replaceAll(RegExp(r'[^0-9kK]'), '');
    
    if (cleanRut.length <= 1) return cleanRut;
    
    // Separar cuerpo y dígito verificador
    String body = cleanRut.substring(0, cleanRut.length - 1);
    String dv = cleanRut.substring(cleanRut.length - 1);
    
    // Formatear con puntos
    String formattedBody = '';
    for (int i = 0; i < body.length; i++) {
      if (i > 0 && (body.length - i) % 3 == 0) {
        formattedBody += '.';
      }
      formattedBody += body[i];
    }
    
    return '$formattedBody-$dv';
  }

  Future<void> _buscarAmigo() async {
    if (!_isValidRut) return;

    setState(() {
      _isLoading = true;
      _usuarioEncontrado = null;
      _errorMessage = '';
    });

    try {
      String rutFormateado = _rutController.text.trim();
      
      // Obtener headers de autenticación
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error de autenticación';
        });
        return;
      }
      
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/user/busquedaRut?rut=$rutFormateado'),
        headers: {
          ...headers,
          'Cache-Control': 'no-cache',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _usuarioEncontrado = data;
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _errorMessage = 'Usuario no encontrado';
          _isLoading = false;
        });
      } else if (response.statusCode == 400) {
        setState(() {
          _errorMessage = 'RUT inválido';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error en la búsqueda';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión';
        _isLoading = false;
      });
    }
  }

  void _agregarAmigo() async {
    if (_usuarioEncontrado != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Enviar solicitud real usando el servicio
        final resultado = await AmistadService.enviarSolicitudAmistad(
          rutReceptor: _usuarioEncontrado!['data']['rut'],
          mensaje: 'Hola, me gustaría agregarte como amigo.',
        );

        setState(() {
          _isLoading = false;
        });

        if (resultado['success']) {
          NotificacionHelpers.mostrarSolicitudEnviada(
            context, 
            _usuarioEncontrado!['data']['nombreCompleto'] ?? 'el usuario'
          );
          
          // Limpiar después de enviar solicitud exitosamente
          _limpiarBusqueda();
        } else {
          NotificacionHelpers.mostrarError(
            context,
            titulo: '❌ Error al enviar solicitud',
            mensaje: resultado['message'] ?? 'No se pudo enviar la solicitud',
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        NotificacionHelpers.mostrarError(
          context,
          titulo: '❌ Error inesperado',
          mensaje: e.toString(),
        );
      }
    }
  }

  void _limpiarBusqueda() {
    _rutController.clear();
    _focusNode.unfocus();
    setState(() {
      _usuarioEncontrado = null;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Agregar Amigo'),
        backgroundColor: const Color(0xFF854937),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            const Text(
              'Buscar por RUT',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B3B2D),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ingresa el RUT de la persona que quieres agregar',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF854937),
              ),
            ),
            const SizedBox(height: 30),
            
            // Barra de búsqueda - igual que antes
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _rutController,
                focusNode: _focusNode,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9kK.-]')),
                  LengthLimitingTextInputFormatter(12),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.isEmpty) return newValue;
                    return TextEditingValue(
                      text: _formatRut(newValue.text),
                      selection: TextSelection.collapsed(
                        offset: _formatRut(newValue.text).length,
                      ),
                    );
                  }),
                ],
                decoration: InputDecoration(
                  hintText: 'Ej: 12.345.678-9',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(
                    Icons.search,
                    color: _isValidRut ? Color(0xFF854937) : Colors.grey[400],
                  ),
                  suffixIcon: _rutController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _limpiarBusqueda,
                          color: Colors.grey[400],
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            
            // Mensaje de error
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Botón de búsqueda
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValidRut && !_isLoading ? _buscarAmigo : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isValidRut ? Color(0xFF854937) : Colors.grey[300],
                  foregroundColor: _isValidRut ? Colors.white : Colors.grey[500],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _isValidRut ? 2 : 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isValidRut ? Icons.person_search : Icons.search_off),
                          const SizedBox(width: 8),
                          Text(
                            _isValidRut ? 'Buscar Usuario' : 'Ingresa un RUT válido',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // 🎯 TARJETA DEL USUARIO ENCONTRADO
            if (_usuarioEncontrado != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: Color(0xFF854937).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icono de usuario
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Color(0xFF854937).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Color(0xFF854937),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Título
                    Text(
                      'Usuario Encontrado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF854937),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Información del usuario
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF8F2EF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow('Nombre', _usuarioEncontrado!['data']?['nombreCompleto'] ?? 'N/A'),
                          const SizedBox(height: 8),
                          _buildInfoRow('RUT', _usuarioEncontrado!['data']?['rut'] ?? 'N/A'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Botón para agregar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _agregarAmigo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isLoading ? Colors.grey[300] : Color(0xFF854937),
                          foregroundColor: _isLoading ? Colors.grey[500] : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: _isLoading ? 0 : 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_add, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Enviar Solicitud',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Información adicional
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF8F2EF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFF3D5C0)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF854937)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El RUT debe incluir el dígito verificador (ej: 12.345.678-9)',
                      style: TextStyle(
                        color: Color(0xFF854937),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF854937),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}