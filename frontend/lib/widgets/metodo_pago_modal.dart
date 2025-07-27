import 'package:flutter/material.dart';
import '../utils/token_manager.dart';
import 'dart:convert';
import '../config/confGlobal.dart';
import 'package:http/http.dart' as http;

class MetodoPagoModal extends StatefulWidget {
  final double precio;
  final String viajeOrigen;
  final String viajeDestino;
  final Function(String metodoPago, Map<String, dynamic>? datosAdicionales, String? mensaje) onPagoSeleccionado;

  const MetodoPagoModal({
    Key? key,
    required this.precio,
    required this.viajeOrigen,
    required this.viajeDestino,
    required this.onPagoSeleccionado,
  }) : super(key: key);

  @override
  State<MetodoPagoModal> createState() => _MetodoPagoModalState();
}

class _MetodoPagoModalState extends State<MetodoPagoModal> {
  String? metodoPagoSeleccionado;
  double saldoDisponible = 0.0;
  List<Map<String, dynamic>> tarjetasDisponibles = [];
  bool isLoading = true;
  Map<String, dynamic>? tarjetaSeleccionada;
  final TextEditingController _mensajeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatosPago();
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosPago() async {
    try {
      setState(() => isLoading = true);
      
      final token = await TokenManager.getValidToken();
      if (token == null) return;
      
      final email = await _getEmailFromToken();
      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/user/detail?email=$email'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          final saldoValue = data['data']['saldo'];
          if (saldoValue is String) {
            saldoDisponible = double.tryParse(saldoValue) ?? 0.0;
          } else {
            saldoDisponible = (saldoValue ?? 0.0).toDouble();
          }
          tarjetasDisponibles = List<Map<String, dynamic>>.from(data['data']['tarjetas'] ?? []);
        });
      }
    } catch (e) {
      print('Error cargando datos de pago: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<String> _getEmailFromToken() async {
    final token = await TokenManager.getValidToken();
    if (token == null) return '';
    
    try {
      final parts = token.split('.');
      if (parts.length != 3) return '';
      
      final payload = parts[1];
      String normalizedPayload = payload;
      while (normalizedPayload.length % 4 != 0) {
        normalizedPayload += '=';
      }
      
      final decodedPayload = utf8.decode(base64Url.decode(normalizedPayload));
      final Map<String, dynamic> tokenData = json.decode(decodedPayload);
      
      return tokenData['email'] ?? '';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8D4F3A),
                  const Color(0xFF6B3B2D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Indicador para arrastrar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.payment, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Método de Pago',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${widget.viajeOrigen} → ${widget.viajeDestino}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Precio: \$${widget.precio.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Contenido
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D4F3A)),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selecciona tu método de pago:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B3B2D),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Opción Saldo
                        _buildMetodoPagoOption(
                          'saldo',
                          'Saldo Disponible',
                          Icons.account_balance_wallet,
                          '\$${saldoDisponible.toStringAsFixed(0)}',
                          saldoDisponible >= widget.precio,
                          subtitle: saldoDisponible < widget.precio 
                              ? 'Saldo insuficiente' 
                              : 'Disponible',
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Opción Tarjetas
                        _buildMetodoPagoOption(
                          'tarjeta',
                          'Tarjetas Guardadas',
                          Icons.credit_card,
                          '${tarjetasDisponibles.length} disponible${tarjetasDisponibles.length != 1 ? 's' : ''}',
                          tarjetasDisponibles.isNotEmpty,
                          subtitle: tarjetasDisponibles.isEmpty 
                              ? 'No hay tarjetas guardadas' 
                              : 'Selecciona una tarjeta',
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Opción Efectivo
                        _buildMetodoPagoOption(
                          'efectivo',
                          'Efectivo',
                          Icons.money,
                          'Pagar al conductor',
                          true,
                          subtitle: 'Disponible',
                        ),
                        
                        // Lista de tarjetas si está seleccionado
                        if (metodoPagoSeleccionado == 'tarjeta' && tarjetasDisponibles.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Selecciona una tarjeta:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B3B2D),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...tarjetasDisponibles.asMap().entries.map(
                            (entry) => _buildTarjetaOption(entry.key, entry.value),
                          ).toList(),
                        ],
                      ],
                    ),
                  ),
          ),
          
          // Campo de mensaje personalizado
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.message_outlined,
                      color: const Color(0xFF6B3B2D),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mensaje al conductor (opcional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B3B2D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _mensajeController,
                  maxLines: 2,
                  maxLength: 150,
                  decoration: InputDecoration(
                    hintText: '¿Puedo unirme a tu viaje?',
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: const Color(0xFF6B3B2D).withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF6B3B2D),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Botón confirmar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: metodoPagoSeleccionado == null ||
                    (metodoPagoSeleccionado == 'saldo' && saldoDisponible < widget.precio) ||
                    (metodoPagoSeleccionado == 'tarjeta' && (tarjetasDisponibles.isEmpty || tarjetaSeleccionada == null))
                    ? null
                    : _confirmarPago,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D4F3A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  metodoPagoSeleccionado == null
                      ? 'Selecciona un método de pago'
                      : 'Confirmar y Unirse al Viaje',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetodoPagoOption(
    String valor,
    String titulo,
    IconData icono,
    String descripcion,
    bool disponible,
    {String? subtitle}
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: disponible ? () {
          setState(() {
            metodoPagoSeleccionado = valor;
            if (valor != 'tarjeta') {
              tarjetaSeleccionada = null;
            }
          });
        } : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: !disponible 
                ? Colors.grey[200] 
                : metodoPagoSeleccionado == valor 
                    ? const Color(0xFF8D4F3A).withOpacity(0.1)
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: !disponible 
                  ? Colors.grey[300]! 
                  : metodoPagoSeleccionado == valor 
                      ? const Color(0xFF8D4F3A)
                      : Colors.grey[300]!,
              width: metodoPagoSeleccionado == valor ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: !disponible 
                      ? Colors.grey[400] 
                      : metodoPagoSeleccionado == valor 
                          ? const Color(0xFF8D4F3A)
                          : const Color(0xFF8D4F3A).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icono,
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
                      titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: !disponible ? Colors.grey[600] : const Color(0xFF6B3B2D),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle ?? descripcion,
                      style: TextStyle(
                        color: !disponible ? Colors.grey[500] : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (metodoPagoSeleccionado == valor) ...[
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF8D4F3A),
                  size: 24,
                ),
              ] else if (!disponible) ...[
                Icon(
                  Icons.lock,
                  color: Colors.grey[500],
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetaOption(int index, Map<String, dynamic> tarjeta) {
    final isSelected = tarjetaSeleccionada == tarjeta;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            tarjetaSeleccionada = tarjeta;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF8D4F3A).withOpacity(0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? const Color(0xFF8D4F3A)
                  : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getCardColor(tarjeta['tipo']),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.credit_card,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '**** ${tarjeta['numero'].toString().substring(tarjeta['numero'].toString().length - 4)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B3B2D),
                      ),
                    ),
                    Text(
                      '${tarjeta['tipo']} - ${tarjeta['nombreTitular']}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF8D4F3A),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
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

  void _confirmarPago() {
    Map<String, dynamic>? datosAdicionales;
    
    switch (metodoPagoSeleccionado) {
      case 'saldo':
        datosAdicionales = {'saldo': saldoDisponible};
        break;
      case 'tarjeta':
        datosAdicionales = {'tarjeta': tarjetaSeleccionada};
        break;
      case 'efectivo':
        datosAdicionales = null;
        break;
    }
    
    // Obtener el mensaje del controller, o usar mensaje por defecto si está vacío
    String mensaje = _mensajeController.text.trim();
    if (mensaje.isEmpty) {
      mensaje = '¿Puedo unirme a tu viaje?';
    }
    
    widget.onPagoSeleccionado(metodoPagoSeleccionado!, datosAdicionales, mensaje);
  }
}
