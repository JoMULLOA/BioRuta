import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/pago_service.dart';

class HistorialPagosPage extends StatefulWidget {
  const HistorialPagosPage({super.key});

  @override
  State<HistorialPagosPage> createState() => _HistorialPagosPageState();
}

class _HistorialPagosPageState extends State<HistorialPagosPage> {
  List<Map<String, dynamic>> _pagos = [];
  bool _isLoading = true;
  String? _errorMessage;

  final Color primario = Color(0xFF6B3B2D);
  final Color secundario = Color(0xFF8D4F3A);
  final Color fondo = Color(0xFFF8F2EF);

  @override
  void initState() {
    super.initState();
    _cargarHistorialPagos();
  }

  Future<void> _cargarHistorialPagos() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final resultado = await PagoService.obtenerMisPagos();

      if (resultado['success'] == true) {
        setState(() {
          _pagos = List<Map<String, dynamic>>.from(resultado['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = resultado['message'] ?? 'Error al cargar pagos';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPagos() async {
    await _cargarHistorialPagos();
  }

  Future<void> _verificarPagosPendientes() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primario),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Verificando estados de pagos...',
                  style: TextStyle(color: secundario),
                ),
              ),
            ],
          ),
        ),
      );

      final resultado = await PagoService.verificarPagosPendientes();
      
      Navigator.of(context).pop(); // Cerrar indicador de carga

      if (resultado['success'] == true) {
        final data = resultado['data'];
        final pagosActualizados = data['pagosActualizados'] ?? 0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pagosActualizados > 0 
                ? 'Se actualizaron $pagosActualizados pagos'
                : 'Todos los pagos están al día'
            ),
            backgroundColor: pagosActualizados > 0 ? Colors.green : Colors.blue,
          ),
        );
        
        if (pagosActualizados > 0) {
          _cargarHistorialPagos(); // Recargar si hubo cambios
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al verificar pagos: ${resultado['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar indicador de carga si existe
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarDetallePago(Map<String, dynamic> pago) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.payment, color: primario),
              SizedBox(width: 8),
              Text(
                'Detalle del Pago',
                style: TextStyle(color: primario, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetalleItem('ID de Pago', pago['id']?.toString() ?? 'N/A'),
                _buildDetalleItem('Viaje ID', pago['viajeId']?.toString() ?? 'N/A'),
                _buildDetalleItem('Monto', '\$${_formatearMonto(pago['montoTotal'])}'),
                _buildDetalleItem('Estado', _getEstadoTexto(pago['estado'])),
                _buildDetalleItem('Descripción', pago['descripcion'] ?? 'Sin descripción'),
                if (pago['paymentId'] != null)
                  _buildDetalleItem('Payment ID (MP)', pago['paymentId']),
                if (pago['preferenceId'] != null)
                  _buildDetalleItem('Preference ID', pago['preferenceId']),
                _buildDetalleItem(
                  'Fecha de Creación', 
                  _formatearFecha(pago['fechaCreacion'])
                ),
                if (pago['fechaActualizacion'] != null)
                  _buildDetalleItem(
                    'Última Actualización', 
                    _formatearFecha(pago['fechaActualizacion'])
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar', style: TextStyle(color: primario)),
            ),
            if (pago['estado'] == 'pendiente')
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _cancelarPago(pago);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                child: Text('Cancelar Pago'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDetalleItem(String titulo, String? valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$titulo: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: secundario,
            ),
          ),
          Expanded(
            child: Text(
              valor ?? 'N/A',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelarPago(Map<String, dynamic> pago) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.cancel, color: Colors.red),
              SizedBox(width: 8),
              Text('Cancelar Pago'),
            ],
          ),
          content: Text(
            '¿Estás seguro de que quieres cancelar este pago?\n\nEsta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: Text('Sí, Cancelar'),
            ),
          ],
        );
      },
    );

    if (confirmado == true) {
      try {
        // Mostrar indicador de carga
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(),
          ),
        );

        final resultado = await PagoService.cancelarPago(pago['id']);

        Navigator.of(context).pop(); // Cerrar indicador de carga

        if (resultado['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pago cancelado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          _cargarHistorialPagos(); // Recargar la lista
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['message'] ?? 'Error al cancelar pago'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        Navigator.of(context).pop(); // Cerrar indicador de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatearMonto(dynamic monto) {
    if (monto == null) return '0';
    
    final numero = double.tryParse(monto.toString()) ?? 0.0;
    final formatter = NumberFormat('#,##0', 'es_CL');
    return formatter.format(numero);
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null) return 'N/A';
    
    try {
      final dateTime = DateTime.parse(fecha);
      final formatter = DateFormat('dd/MM/yyyy HH:mm', 'es_CL');
      return formatter.format(dateTime);
    } catch (e) {
      return fecha;
    }
  }

  String _getEstadoTexto(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'pendiente':
        return 'Pendiente';
      case 'aprobado':
        return 'Aprobado';
      case 'rechazado':
        return 'Rechazado';
      case 'cancelado':
        return 'Cancelado';
      case 'completado':
        return 'Completado';
      default:
        return 'Desconocido';
    }
  }

  Color _getEstadoColor(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'aprobado':
      case 'completado':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'rechazado':
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPagoCard(Map<String, dynamic> pago) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _mostrarDetallePago(pago),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con monto y estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${_formatearMonto(pago['montoTotal'])}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primario,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getEstadoColor(pago['estado']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getEstadoColor(pago['estado']),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getEstadoTexto(pago['estado']),
                      style: TextStyle(
                        color: _getEstadoColor(pago['estado']),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              
              // Descripción
              if (pago['descripcion'] != null)
                Text(
                  pago['descripcion'],
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              
              SizedBox(height: 8),
              
              // Footer con fecha y viaje ID
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        _formatearFecha(pago['fechaCreacion']),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (pago['viajeId'] != null)
                    Row(
                      children: [
                        Icon(Icons.directions_car, size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          'Viaje #${pago['viajeId']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: Text('Historial de Pagos'),
        backgroundColor: secundario,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Botón para verificar pagos pendientes
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Verificar estados de pagos',
            onPressed: _verificarPagosPendientes,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primario),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cargando historial de pagos...',
                    style: TextStyle(color: secundario),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red[600],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargarHistorialPagos,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primario,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _pagos.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _refreshPagos,
                      color: primario,
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.payment_outlined,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Aún no hay pagos',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: secundario,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Cuando realices un pago por un viaje,\naparecerá aquí',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 24),
                                Text(
                                  'Desliza hacia abajo para actualizar',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refreshPagos,
                      color: primario,
                      child: ListView.builder(
                        padding: EdgeInsets.only(top: 16, bottom: 16),
                        itemCount: _pagos.length,
                        itemBuilder: (context, index) {
                          return _buildPagoCard(_pagos[index]);
                        },
                      ),
                    ),
    );
  }
}
