import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/token_manager.dart';
import '../config/confGlobal.dart';

class SaldoTarjetasScreen extends StatefulWidget {
  const SaldoTarjetasScreen({Key? key}) : super(key: key);

  @override
  State<SaldoTarjetasScreen> createState() => _SaldoTarjetasScreenState();
}

class _SaldoTarjetasScreenState extends State<SaldoTarjetasScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  double saldoActual = 0.0;
  List<Map<String, dynamic>> misTarjetas = [];
  List<Map<String, dynamic>> historialTransacciones = [];
  bool isLoading = true;

  // Controladores para el formulario de agregar tarjeta
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _vencimientoController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Cambiar a 2 pestañas
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Dispose de los controladores del formulario
    _numeroController.dispose();
    _cvvController.dispose();
    _vencimientoController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    if (mounted) {
      setState(() => isLoading = true);
    }
    await Future.wait([
      _cargarSaldo(),
      _cargarMisTarjetas(),
      _cargarHistorial(),
    ]);
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // Método público para recargar datos desde otras pantallas
  Future<void> recargarDatos() async {
    await _cargarDatos();
  }

  Future<void> _cargarSaldo() async {
    try {
      final token = await TokenManager.getValidToken();
      if (token == null) return;
      
      // Usar el endpoint detail del usuario con el email del token
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/user/detail?email=${await _getEmailFromToken()}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response data: $data'); // Debug
        if (mounted) {
          setState(() {
            // Manejar tanto string como double para el saldo
            final saldoValue = data['data']['saldo'];
            if (saldoValue is String) {
              saldoActual = double.tryParse(saldoValue) ?? 0.0;
            } else {
              saldoActual = (saldoValue ?? 0.0).toDouble();
            }
          });
        }
      } else {
        print('Error response: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error al cargar saldo: $e');
    }
  }

  Future<String> _getEmailFromToken() async {
    final token = await TokenManager.getValidToken();
    if (token == null) return '';
    
    try {
      // Decodificar el JWT para obtener el email
      final parts = token.split('.');
      if (parts.length != 3) return '';
      
      final payload = parts[1];
      // Normalizar el payload base64
      String normalizedPayload = payload;
      while (normalizedPayload.length % 4 != 0) {
        normalizedPayload += '=';
      }
      
      final decodedPayload = utf8.decode(base64Url.decode(normalizedPayload));
      final Map<String, dynamic> tokenData = json.decode(decodedPayload);
      
      return tokenData['email'] ?? '';
    } catch (e) {
      print('Error decodificando token: $e');
      return '';
    }
  }

  Future<void> _cargarMisTarjetas() async {
    try {
      final token = await TokenManager.getValidToken();
      if (token == null) return;
      
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/user/detail?email=${await _getEmailFromToken()}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Tarjetas response: $data'); // Debug
        if (mounted) {
          setState(() {
            misTarjetas = List<Map<String, dynamic>>.from(data['data']['tarjetas'] ?? []);
          });
        }
      } else {
        print('Error tarjetas: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error al cargar mis tarjetas: $e');
    }
  }





  Future<void> _agregarTarjeta(String numeroTarjeta, String cvv, String fechaVencimiento, String nombreTitular) async {
    if (!mounted) return; // Verificar si el widget está montado antes de comenzar
    
    try {
      final token = await TokenManager.getValidToken();
      if (token == null) {
        if (mounted) _mostrarMensaje('Error de autenticación', isError: true);
        return;
      }
      
      // Crear objeto de tarjeta
      final nuevaTarjeta = {
        'numero': numeroTarjeta,
        'cvv': cvv,
        'fechaVencimiento': fechaVencimiento,
        'nombreTitular': nombreTitular,
        'tipo': _detectarTipoTarjeta(numeroTarjeta),
        'banco': 'Banco Sandbox',
        'limiteCredito': 500000,
      };
      
      // Agregar a la lista local y actualizar en el servidor
      final tarjetasActualizadas = [...misTarjetas, nuevaTarjeta];
      final email = await _getEmailFromToken();
      
      print('Enviando tarjeta al backend: ${json.encode({'tarjetas': tarjetasActualizadas})}');
      
      final response = await http.patch(
        Uri.parse('${confGlobal.baseUrl}/user/actualizar?email=$email'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'tarjetas': tarjetasActualizadas}),
      );

      // Verificar que el widget siga montado antes de actualizar el estado o mostrar mensajes
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          misTarjetas = tarjetasActualizadas;
        });
        // Usar Future.delayed para asegurar que el contexto esté disponible
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _mostrarMensaje('Tarjeta agregada exitosamente');
        });
      } else {
        print('Error response: ${response.statusCode} - ${response.body}');
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _mostrarMensaje('Error al agregar tarjeta', isError: true);
        });
      }
    } catch (e) {
      print('Exception al agregar tarjeta: $e');
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _mostrarMensaje('Error al agregar tarjeta', isError: true);
        });
      }
    }
  }

  String _detectarTipoTarjeta(String numero) {
    numero = numero.replaceAll('-', '').replaceAll(' ', '');
    if (numero.startsWith('4')) return 'VISA';
    if (numero.startsWith('5')) return 'MASTERCARD';
    if (numero.startsWith('37') || numero.startsWith('34')) return 'AMERICAN_EXPRESS';
    return 'VISA';
  }

  void _mostrarDialogoAgregarTarjeta() {
    // Limpiar los controladores antes de mostrar el diálogo
    _numeroController.clear();
    _cvvController.clear();
    _vencimientoController.clear();
    _nombreController.clear();

    // Función para formatear el número de tarjeta
    void formatearNumeroTarjeta(String value) {
      String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length > 16) digits = digits.substring(0, 16);
      
      String formatted = '';
      for (int i = 0; i < digits.length; i++) {
        if (i > 0 && i % 4 == 0) formatted += '-';
        formatted += digits[i];
      }
      
      _numeroController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    // Función para formatear la fecha de vencimiento
    void formatearFechaVencimiento(String value) {
      String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length > 6) digits = digits.substring(0, 6);
      
      String formatted = '';
      if (digits.length >= 2) {
        formatted = digits.substring(0, 2);
        if (digits.length > 2) {
          formatted += '/${digits.substring(2)}';
        }
      } else {
        formatted = digits;
      }
      
      _vencimientoController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF2EEED),
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8D4F3A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.credit_card,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Agregar Nueva Tarjeta',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B3B2D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Número de tarjeta
                _buildInputField(
                  controller: _numeroController,
                  label: 'Número de Tarjeta',
                  hint: '4111-1111-1111-1111',
                  icon: Icons.credit_card,
                  keyboardType: TextInputType.number,
                  onChanged: formatearNumeroTarjeta,
                  maxLength: 19, // 16 dígitos + 3 guiones
                ),
                const SizedBox(height: 16),
                
                // CVV y Vencimiento en fila
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildInputField(
                        controller: _cvvController,
                        label: 'CVV',
                        hint: '123',
                        icon: Icons.security,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildInputField(
                        controller: _vencimientoController,
                        label: 'Vencimiento',
                        hint: 'MM/YYYY',
                        icon: Icons.calendar_today,
                        keyboardType: TextInputType.number,
                        onChanged: formatearFechaVencimiento,
                        maxLength: 7, // MM/YYYY = 7 caracteres
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Nombre del titular
                _buildInputField(
                  controller: _nombreController,
                  label: 'Nombre del Titular',
                  hint: 'Juan Pérez',
                  icon: Icons.person,
                ),
                const SizedBox(height: 24),
                
                // Botones
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFF8D4F3A)),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Color(0xFF8D4F3A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Validación básica
                          final numero = _numeroController.text.replaceAll('-', '');
                          final cvv = _cvvController.text;
                          final vencimiento = _vencimientoController.text;
                          final nombre = _nombreController.text;
                          
                          if (numero.isEmpty || numero.length < 13 || numero.length > 19) {
                            _mostrarMensaje('Número de tarjeta inválido (debe tener entre 13-19 dígitos)', isError: true);
                            return;
                          }
                          if (cvv.isEmpty || cvv.length < 3 || cvv.length > 4) {
                            _mostrarMensaje('CVV inválido (debe tener 3-4 dígitos)', isError: true);
                            return;
                          }
                          if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{4}$').hasMatch(vencimiento)) {
                            _mostrarMensaje('Fecha de vencimiento inválida (formato MM/YYYY)', isError: true);
                            return;
                          }
                          if (nombre.isEmpty || nombre.length < 2) {
                            _mostrarMensaje('Nombre del titular inválido', isError: true);
                            return;
                          }
                          
                          // Validar que la fecha no sea pasada
                          try {
                            final fechaPartes = vencimiento.split('/');
                            final mes = int.parse(fechaPartes[0]);
                            final anio = int.parse(fechaPartes[1]);
                            final fechaVencimiento = DateTime(anio, mes);
                            final ahora = DateTime.now();
                            final fechaActual = DateTime(ahora.year, ahora.month);
                            
                            if (fechaVencimiento.isBefore(fechaActual)) {
                              _mostrarMensaje('La tarjeta está vencida', isError: true);
                              return;
                            }
                          } catch (e) {
                            _mostrarMensaje('Error al validar fecha de vencimiento', isError: true);
                            return;
                          }
                          
                          // Cerrar el diálogo primero para evitar problemas de estado
                          if (Navigator.canPop(context)) {
                            Navigator.of(context).pop();
                          }
                          
                          // Esperar un poco antes de ejecutar la agregación para asegurar que el diálogo se haya cerrado completamente
                          await Future.delayed(const Duration(milliseconds: 200));
                          
                          // Ejecutar la agregación de tarjeta solo si el widget aún está montado
                          if (mounted) {
                            await _agregarTarjeta(
                              _numeroController.text, // Mantener con guiones para mostrar
                              _cvvController.text,
                              _vencimientoController.text,
                              _nombreController.text,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8D4F3A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Agregar Tarjeta',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B3B2D),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF8D4F3A)),
            counterText: maxLength != null ? '' : null, // Ocultar contador cuando hay maxLength
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEDCAB6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEDCAB6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8D4F3A), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }



  Future<void> _removerTarjeta(int index) async {
    if (!mounted) return; // Verificar si el widget está montado antes de comenzar
    
    try {
      final token = await TokenManager.getValidToken();
      if (token == null) {
        if (mounted) _mostrarMensaje('Error de autenticación', isError: true);
        return;
      }
      
      // Remover de la lista local
      final tarjetasActualizadas = [...misTarjetas];
      tarjetasActualizadas.removeAt(index);
      
      final email = await _getEmailFromToken();
      final response = await http.patch(
        Uri.parse('${confGlobal.baseUrl}/user/actualizar?email=$email'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'tarjetas': tarjetasActualizadas}),
      );

      // Verificar que el widget siga montado antes de actualizar el estado o mostrar mensajes
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          misTarjetas = tarjetasActualizadas;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _mostrarMensaje('Tarjeta removida exitosamente');
        });
      } else {
        print('Error response: ${response.statusCode} - ${response.body}');
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _mostrarMensaje('Error al remover tarjeta', isError: true);
        });
      }
    } catch (e) {
      print('Exception al remover tarjeta: $e');
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _mostrarMensaje('Error al remover tarjeta', isError: true);
        });
      }
    }
  }

  void _mostrarMensaje(String mensaje, {bool isError = false}) {
    // Solo mostrar el mensaje si el widget está montado y el context es válido
    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: isError ? Colors.red : const Color(0xFF8D4F3A),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // Si no podemos mostrar el SnackBar, al menos loggeamos el mensaje
      print('Mensaje no mostrado (widget desmontado): $mensaje');
    }
  }



  Widget _buildSaldoTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF2EEED),
            Colors.white,
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card de saldo actual
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF8D4F3A),
                    const Color(0xFF6B3B2D),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B3B2D).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Saldo Disponible',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFEDCAB6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${saldoActual.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
          
            
            const SizedBox(height: 30),
            
            // Título del historial
            const Text(
              'Historial de Transacciones',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B3B2D),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Lista del historial
            historialTransacciones.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEDCAB6).withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDCAB6).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Icon(
                            Icons.history,
                            size: 48,
                            color: Color(0xFF8D4F3A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay transacciones aún',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B3B2D),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cuando realices pagos o recibas dinero\naparecerán aquí',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8D4F3A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: historialTransacciones
                        .map((transaccion) => _buildTransaccionCard(transaccion))
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetasTab() {
    return _buildMisTarjetas();
  }

  Widget _buildMisTarjetas() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF2EEED),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          // Botones de acción
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Botón para agregar tarjeta
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _mostrarDialogoAgregarTarjeta,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Agregar Tarjeta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF8D4F3A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botón para recargar
                Container(
                  height: 48,
                  child: IconButton(
                    onPressed: () async {
                      await _cargarDatos();
                      _mostrarMensaje('Datos actualizados');
                    },
                    icon: const Icon(Icons.refresh),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF8D4F3A).withOpacity(0.1),
                      foregroundColor: const Color(0xFF8D4F3A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    tooltip: 'Actualizar límites',
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de tarjetas
          Expanded(
            child: misTarjetas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDCAB6).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.credit_card_off, 
                          size: 64, 
                          color: Color(0xFF8D4F3A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No tienes tarjetas asignadas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B3B2D),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Usa el botón "Agregar Tarjeta" para añadir una',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8D4F3A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: misTarjetas.length,
                  itemBuilder: (context, index) {
                    final tarjeta = misTarjetas[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            const Color(0xFFF2EEED),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6B3B2D).withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getCardColor(tarjeta['tipo']),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.credit_card,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          tarjeta['numero'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B3B2D),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              tarjeta['nombreTitular'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8D4F3A),
                              ),
                            ),
                            Text(
                              '${tarjeta['banco']} - ${tarjeta['fechaVencimiento']}',
                              style: const TextStyle(
                                color: Color(0xFF6B3B2D),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Límite: \$${(tarjeta['limiteCredito'] ?? 0).toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFF8D4F3A),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _mostrarDialogoRemoverTarjeta(tarjeta, index),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }



  void _mostrarDialogoRemoverTarjeta(Map<String, dynamic> tarjeta, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Tarjeta'),
        content: Text('¿Estás seguro de que deseas remover la tarjeta ${tarjeta['numero']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removerTarjeta(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _cargarHistorial() async {
    try {
      final token = await TokenManager.getValidToken();
      if (token == null) return;
      
      final email = await _getEmailFromToken();
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/user/historial-transacciones?email=$email'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Historial response: $data'); // Debug
        if (mounted) {
          setState(() {
            historialTransacciones = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
        }
      } else {
        print('Error historial: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error al cargar historial: $e');
    }
  }

  Widget _buildTransaccionCard(Map<String, dynamic> transaccion) {
    final double monto = (transaccion['monto'] ?? 0.0).toDouble();
    final String tipo = transaccion['tipo'] ?? 'pago';
    final String metodoPago = transaccion['metodo_pago'] ?? '';
    final String estado = transaccion['estado'] ?? 'completado';
    final DateTime fecha = DateTime.parse(transaccion['fecha'] ?? DateTime.now().toIso8601String());
    
    // Para mostrar correctamente: 
    // - Pago: monto negativo (-), flecha hacia abajo, rojo
    // - Cobro: monto positivo (+), flecha hacia arriba, verde
    // - Devolución: puede ser positiva (pasajero recibe) o negativa (conductor pierde)
    bool esPositivo = false;
    double montoMostrar = monto;
    final String concepto = transaccion['concepto']?.toLowerCase() ?? '';
    
    switch (tipo.toLowerCase()) {
      case 'pago':
        esPositivo = false; // Negativo para el que paga
        montoMostrar = -monto.abs(); // Asegurar que sea negativo
        break;
      case 'cobro':
        esPositivo = true; // Positivo para el que cobra
        montoMostrar = monto.abs(); // Asegurar que sea positivo
        break;
      case 'devolucion':
        // Verificar si es un ajuste por abandono (negativo para conductor) o devolución normal (positivo para pasajero)
        if (concepto.contains('ajuste por abandono') || concepto.contains('ajuste por eliminación') || monto < 0) {
          esPositivo = false; // Negativo para ajustes del conductor
          montoMostrar = -monto.abs(); // Asegurar que sea negativo
        } else {
          esPositivo = true; // Positivo para devoluciones al pasajero
          montoMostrar = monto.abs(); // Asegurar que sea positivo
        }
        break;
    }
    
    // Determinar si es una transacción en efectivo pendiente que puede confirmar
    final bool esEfectivoPendiente = metodoPago == 'efectivo' && estado == 'pendiente';
    
    // Solo el receptor del pago (conductor) puede confirmar pagos en efectivo
    // Si es tipo 'cobro', significa que este usuario es el conductor que recibe el pago
    final bool puedeConfirmar = esEfectivoPendiente && tipo.toLowerCase() == 'cobro';
    
    // Verificar que el ID de transacción no sea null
    final String? transaccionId = transaccion['_id'] ?? transaccion['id'];
    final bool tieneIdValido = transaccionId != null && transaccionId.isNotEmpty;
    
    Widget cardContent = Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: esEfectivoPendiente 
              ? Colors.orange.withOpacity(0.5) 
              : const Color(0xFFEDCAB6).withOpacity(0.5), 
          width: esEfectivoPendiente ? 2 : 1
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getTipoTransaccionColor(tipo, concepto: concepto, monto: monto),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTipoTransaccionIcon(tipo, concepto: concepto, monto: monto),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaccion['concepto'] ?? 'Transacción',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B3B2D),
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _formatearFechaTransaccion(fecha),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _getMetodoPagoIcon(metodoPago),
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getMetodoPagoTexto(metodoPago),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${esPositivo ? '+' : ''}\$${montoMostrar.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: esPositivo ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: estado == 'completado' 
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        estado,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: estado == 'completado' 
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Mostrar instrucciones para pagos en efectivo pendientes
            if (puedeConfirmar && tieneIdValido) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mantén presionado para confirmar cuando se realice el pago en efectivo',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (esEfectivoPendiente && !puedeConfirmar) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      color: Colors.blue[700],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esperando confirmación del conductor',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
    
    // Solo permitir confirmación si es efectivo pendiente, el usuario puede confirmar y tiene ID válido
    if (puedeConfirmar && tieneIdValido) {
      return GestureDetector(
        onLongPress: () => _confirmarPagoEfectivo(transaccion),
        child: cardContent,
      );
    }
    
    return cardContent;
  }

  Color _getTipoTransaccionColor(String tipo, {String concepto = '', double monto = 0}) {
    switch (tipo.toLowerCase()) {
      case 'cobro':
        return Colors.green; // Verde para dinero recibido
      case 'pago':
        return Colors.red; // Rojo para dinero gastado
      case 'devolucion':
        // Si es un ajuste por abandono o monto negativo, usar rojo (pérdida)
        if (concepto.toLowerCase().contains('ajuste por abandono') || 
            concepto.toLowerCase().contains('ajuste por eliminación') || 
            monto < 0) {
          return Colors.red; // Rojo para ajustes de conductor (pérdida de dinero)
        }
        return Colors.blue; // Azul para devoluciones normales (ganancia de dinero)
      default:
        return const Color(0xFF8D4F3A);
    }
  }

  IconData _getTipoTransaccionIcon(String tipo, {String concepto = '', double monto = 0}) {
    switch (tipo.toLowerCase()) {
      case 'cobro':
        return Icons.arrow_upward; // Flecha hacia arriba para dinero recibido
      case 'pago':
        return Icons.arrow_downward; // Flecha hacia abajo para dinero gastado  
      case 'devolucion':
        // Si es un ajuste por abandono o monto negativo, usar flecha hacia abajo
        if (concepto.toLowerCase().contains('ajuste por abandono') || 
            concepto.toLowerCase().contains('ajuste por eliminación') || 
            monto < 0) {
          return Icons.arrow_downward; // Flecha hacia abajo para ajustes del conductor
        }
        return Icons.refresh; // Flecha circular para devoluciones normales
      default:
        return Icons.swap_horiz;
    }
  }

  String _formatearFechaTransaccion(DateTime fecha) {
    final now = DateTime.now();
    final difference = now.difference(fecha);
    
    if (difference.inDays == 0) {
      return 'Hoy ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ayer ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} días atrás';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }

  IconData _getMetodoPagoIcon(String metodo) {
    switch (metodo.toLowerCase()) {
      case 'saldo':
        return Icons.account_balance_wallet;
      case 'tarjeta':
        return Icons.credit_card;
      case 'efectivo':
        return Icons.money;
      default:
        return Icons.payment;
    }
  }

  String _getMetodoPagoTexto(String metodo) {
    switch (metodo.toLowerCase()) {
      case 'saldo':
        return 'Saldo';
      case 'tarjeta':
        return 'Tarjeta';
      case 'efectivo':
        return 'Efectivo';
      default:
        return metodo;
    }
  }

  Color _getCardColor(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'visa':
        return const Color(0xFF1A73E8);
      case 'mastercard':
        return const Color(0xFFEB5424);
      case 'american_express':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF8D4F3A);
    }
  }

  Future<void> _confirmarPagoEfectivo(Map<String, dynamic> transaccion) async {
    try {
      // Verificar que tengamos un ID válido
      final String? transaccionId = transaccion['_id'] ?? transaccion['id'];
      if (transaccionId == null || transaccionId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: ID de transacción no válido'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Mostrar diálogo de confirmación
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirmar Pago en Efectivo'),
            content: Text(
              '¿Confirmas que se ha realizado el pago en efectivo de \$${transaccion['monto']?.toStringAsFixed(0)} por "${transaccion['concepto']}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D4F3A),
                ),
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      );

      if (confirmar == true) {
        // Realizar la confirmación en el backend
        final token = await TokenManager.getValidToken();
        if (token == null) return;
        
        print('Confirmando transacción ID: $transaccionId'); // Debug
        
        final response = await http.patch(
          Uri.parse('${confGlobal.baseUrl}/transacciones/confirmar-efectivo/$transaccionId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        print('Response status: ${response.statusCode}'); // Debug
        print('Response body: ${response.body}'); // Debug

        if (response.statusCode == 200) {
          // Mostrar mensaje de éxito
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pago en efectivo confirmado exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Actualizar la lista de transacciones
            _cargarDatos();
          }
        } else {
          throw Exception('Error al confirmar el pago: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      print('Error al confirmar pago efectivo: $e'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al confirmar el pago: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saldo y Tarjetas'),
        backgroundColor: const Color(0xFF8D4F3A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFEDCAB6),
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Saldo'),
            Tab(icon: Icon(Icons.credit_card), text: 'Tarjetas'),
          ],
        ),
      ),
      body: isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D4F3A)),
            ),
          )
        : TabBarView(
            controller: _tabController,
            children: [
              _buildSaldoTab(),
              _buildTarjetasTab(),
            ],
          ),
    );
  }
}
