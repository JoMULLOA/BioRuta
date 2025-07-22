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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Cambiar a 2 pestañas
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => isLoading = true);
    await Future.wait([
      _cargarSaldo(),
      _cargarMisTarjetas(),
      _cargarHistorial(),
    ]);
    setState(() => isLoading = false);
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
        setState(() {
          // Manejar tanto string como double para el saldo
          final saldoValue = data['data']['saldo'];
          if (saldoValue is String) {
            saldoActual = double.tryParse(saldoValue) ?? 0.0;
          } else {
            saldoActual = (saldoValue ?? 0.0).toDouble();
          }
        });
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
        setState(() {
          misTarjetas = List<Map<String, dynamic>>.from(data['data']['tarjetas'] ?? []);
        });
      } else {
        print('Error tarjetas: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error al cargar mis tarjetas: $e');
    }
  }





  Future<void> _agregarTarjeta(String numeroTarjeta, String cvv, String fechaVencimiento, String nombreTitular) async {
    try {
      final token = await TokenManager.getValidToken();
      if (token == null) return;
      
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
      
      final response = await http.patch(
        Uri.parse('${confGlobal.baseUrl}/user/actualizar?email=$email'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'tarjetas': tarjetasActualizadas}),
      );

      if (response.statusCode == 200) {
        setState(() {
          misTarjetas = tarjetasActualizadas;
        });
        _mostrarMensaje('Tarjeta agregada exitosamente');
        Navigator.of(context).pop();
      } else {
        _mostrarMensaje('Error al agregar tarjeta', isError: true);
      }
    } catch (e) {
      _mostrarMensaje('Error al agregar tarjeta', isError: true);
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
    final numeroController = TextEditingController();
    final cvvController = TextEditingController();
    final vencimientoController = TextEditingController();
    final nombreController = TextEditingController();

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
                  controller: numeroController,
                  label: 'Número de Tarjeta',
                  hint: '4111-1111-1111-1111',
                  icon: Icons.credit_card,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                // CVV y Vencimiento en fila
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildInputField(
                        controller: cvvController,
                        label: 'CVV',
                        hint: '123',
                        icon: Icons.security,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildInputField(
                        controller: vencimientoController,
                        label: 'Vencimiento',
                        hint: 'MM/YYYY',
                        icon: Icons.calendar_today,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Nombre del titular
                _buildInputField(
                  controller: nombreController,
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
                        onPressed: () => Navigator.of(context).pop(),
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
                        onPressed: () {
                          if (numeroController.text.isNotEmpty && 
                              cvvController.text.isNotEmpty && 
                              vencimientoController.text.isNotEmpty &&
                              nombreController.text.isNotEmpty) {
                            _agregarTarjeta(
                              numeroController.text,
                              cvvController.text,
                              vencimientoController.text,
                              nombreController.text,
                            );
                          } else {
                            _mostrarMensaje('Completa todos los campos', isError: true);
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
    ).then((_) {
      numeroController.dispose();
      cvvController.dispose();
      vencimientoController.dispose();
      nombreController.dispose();
    });
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
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
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF8D4F3A)),
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
    try {
      final token = await TokenManager.getValidToken();
      if (token == null) return;
      
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

      if (response.statusCode == 200) {
        setState(() {
          misTarjetas = tarjetasActualizadas;
        });
        _mostrarMensaje('Tarjeta removida exitosamente');
      } else {
        _mostrarMensaje('Error al remover tarjeta', isError: true);
      }
    } catch (e) {
      _mostrarMensaje('Error al remover tarjeta', isError: true);
    }
  }

  void _mostrarMensaje(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: isError ? Colors.red : const Color(0xFF8D4F3A),
        duration: const Duration(seconds: 2),
      ),
    );
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
            
            // Información del sandbox
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEDCAB6).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8D4F3A).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.info, color: Color(0xFF8D4F3A)),
                  SizedBox(height: 8),
                  Text(
                    'Modo Sandbox',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B3B2D),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Este es tu saldo actual para realizar pagos en la aplicación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B3B2D),
                    ),
                  ),
                ],
              ),
            ),
            
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
          // Botón para agregar tarjeta
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
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
        setState(() {
          historialTransacciones = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      } else {
        print('Error historial: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error al cargar historial: $e');
      // Si hay error, crear historial dummy para mostrar funcionalidad
      setState(() {
        historialTransacciones = [
          {
            'id': '1',
            'tipo': 'pago',
            'concepto': 'Pago por viaje compartido - Viaje ID: 123',
            'monto': 8500.0, // Positivo en BD, se mostrará como negativo
            'fecha': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            'estado': 'completado',
            'metodo_pago': 'saldo'
          },
          {
            'id': '2',
            'tipo': 'cobro',
            'concepto': 'Pago por viaje compartido - Viaje ID: 124',
            'monto': 12000.0, // Positivo en BD, se mostrará como positivo
            'fecha': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
            'estado': 'completado',
            'metodo_pago': 'saldo'
          },
          {
            'id': '3',
            'tipo': 'devolucion',
            'concepto': 'Devolución por viaje cancelado - Viaje ID: 125',
            'monto': 7000.0, // Positivo en BD, se mostrará como positivo
            'fecha': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
            'estado': 'completado',
            'metodo_pago': 'saldo'
          }
        ];
      });
    }
  }

  Widget _buildTransaccionCard(Map<String, dynamic> transaccion) {
    final double monto = (transaccion['monto'] ?? 0.0).toDouble();
    final String tipo = transaccion['tipo'] ?? 'pago';
    final DateTime fecha = DateTime.parse(transaccion['fecha'] ?? DateTime.now().toIso8601String());
    
    // Para mostrar correctamente: 
    // - Pago: monto negativo (-), flecha hacia abajo, rojo
    // - Cobro: monto positivo (+), flecha hacia arriba, verde
    // - Devolución: monto positivo (+), flecha circular, azul
    bool esPositivo = false;
    double montoMostrar = monto;
    
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
        esPositivo = true; // Positivo para el que recibe devolución
        montoMostrar = monto.abs(); // Asegurar que sea positivo
        break;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFEDCAB6).withOpacity(0.5), width: 1),
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
                    color: _getTipoTransaccionColor(tipo),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTipoTransaccionIcon(tipo),
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
                      Text(
                        _formatearFechaTransaccion(fecha),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
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
                        color: transaccion['estado'] == 'completado' 
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        transaccion['estado'] ?? 'pendiente',
                        style: TextStyle(
                          fontSize: 10,
                          color: transaccion['estado'] == 'completado' 
                              ? Colors.green[700]
                              : Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (transaccion['metodo_pago'] != null) ...[
              const SizedBox(height: 8),
              Divider(color: Colors.grey[300], height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _getMetodoPagoIcon(transaccion['metodo_pago']),
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Método: ${_getMetodoPagoTexto(transaccion['metodo_pago'])}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getTipoTransaccionColor(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'cobro':
        return Colors.green; // Verde para dinero recibido
      case 'pago':
        return Colors.red; // Rojo para dinero gastado
      case 'devolucion':
        return Colors.blue; // Azul para devoluciones
      default:
        return const Color(0xFF8D4F3A);
    }
  }

  IconData _getTipoTransaccionIcon(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'cobro':
        return Icons.arrow_upward; // Flecha hacia arriba para dinero recibido
      case 'pago':
        return Icons.arrow_downward; // Flecha hacia abajo para dinero gastado  
      case 'devolucion':
        return Icons.refresh; // Flecha circular para devoluciones
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
