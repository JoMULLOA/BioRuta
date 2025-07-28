import 'package:flutter/material.dart';
import '../models/reporte_model.dart';
import '../services/reporte_service.dart';

class GestionReportesScreen extends StatefulWidget {
  const GestionReportesScreen({Key? key}) : super(key: key);

  @override
  _GestionReportesScreenState createState() => _GestionReportesScreenState();
}

class _GestionReportesScreenState extends State<GestionReportesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Reporte> _reportes = [];
  bool _isLoading = true;
  String _filtroEstado = '';
  Map<String, dynamic> _estadisticas = {};

  final Color _primaryColor = Color(0xFF8D4F3A);
  final Color _backgroundColor = Color(0xFFF8F2EF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
    });

    // Cargar reportes y estadísticas en paralelo
    final futures = await Future.wait([
      ReporteService.obtenerTodosLosReportes(estado: _filtroEstado),
      ReporteService.obtenerEstadisticasReportes(),
    ]);

    final reportesResult = futures[0];
    final estadisticasResult = futures[1];

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (reportesResult['success']) {
          _reportes = reportesResult['reportes'] ?? [];
        }
        if (estadisticasResult['success']) {
          _estadisticas = estadisticasResult['estadisticas'] ?? {};
        }
      });
    }
  }

  Future<void> _actualizarEstadoReporte(
      Reporte reporte, EstadoReporte nuevoEstado) async {
    final resultado = await ReporteService.actualizarEstadoReporte(
      reporteId: reporte.id!,
      nuevoEstado: nuevoEstado,
    );

    if (resultado['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      _cargarDatos(); // Recargar datos
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              resultado['message'] ?? 'Error al actualizar el estado'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Gestión de Reportes'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.report),
              text: 'Reportes',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: 'Estadísticas',
            ),
            Tab(
              icon: Icon(Icons.filter_alt),
              text: 'Filtros',
            ),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportesTab(),
          _buildEstadisticasTab(),
          _buildFiltrosTab(),
        ],
      ),
    );
  }

  Widget _buildReportesTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }

    if (_reportes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.report_off,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No hay reportes disponibles',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      color: _primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _reportes.length,
        itemBuilder: (context, index) {
          return _buildReporteCard(_reportes[index]);
        },
      ),
    );
  }

  Widget _buildReporteCard(Reporte reporte) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: reporte.estado.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con tipo y estado
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reporte.tipoReporte.displayName,
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: reporte.estado.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reporte.estado.displayName,
                    style: TextStyle(
                      color: reporte.estado.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Información del reporte
            Row(
              children: [
                Icon(Icons.person, size: 18, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  'Reportado: ${reporte.usuarioReportado}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            SizedBox(height: 8),

            Row(
              children: [
                Icon(Icons.warning, size: 18, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Motivo: ${reporte.motivo.displayName}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            if (reporte.descripcion != null && reporte.descripcion!.isNotEmpty) ...[
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.description, size: 18, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reporte.descripcion!,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: 12),

            // Fecha
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[500]),
                SizedBox(width: 6),
                Text(
                  _formatearFecha(reporte.fechaCreacion),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Acciones
            if (reporte.estado == EstadoReporte.pendiente) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _actualizarEstadoReporte(
                          reporte, EstadoReporte.aceptado),
                      icon: Icon(Icons.check, size: 18),
                      label: Text('Aceptar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _actualizarEstadoReporte(
                          reporte, EstadoReporte.rechazado),
                      icon: Icon(Icons.close, size: 18),
                      label: Text('Rechazar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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

  Widget _buildEstadisticasTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Estadísticas generales
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estadísticas Generales',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildEstadisticaItem(
                    'Total de Reportes',
                    _estadisticas['totalReportes']?.toString() ?? '0',
                    Icons.report,
                    Colors.blue,
                  ),
                  _buildEstadisticaItem(
                    'Reportes Pendientes',
                    _estadisticas['reportesPendientes']?.toString() ?? '0',
                    Icons.pending,
                    Colors.orange,
                  ),
                  _buildEstadisticaItem(
                    'Reportes Aceptados',
                    _estadisticas['reportesAceptados']?.toString() ?? '0',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildEstadisticaItem(
                    'Reportes Rechazados',
                    _estadisticas['reportesRechazados']?.toString() ?? '0',
                    Icons.cancel,
                    Colors.red,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticaItem(
      String titulo, String valor, IconData icono, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icono, color: color, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltrosTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtrar Reportes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          SizedBox(height: 16),
          
          Text(
            'Estado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text('Todos'),
                selected: _filtroEstado == '',
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _filtroEstado = '';
                    });
                    _cargarDatos();
                  }
                },
                selectedColor: _primaryColor.withOpacity(0.2),
              ),
              ...EstadoReporte.values.map((estado) => FilterChip(
                    label: Text(estado.displayName),
                    selected: _filtroEstado == estado.toString().split('.').last,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _filtroEstado = estado.toString().split('.').last;
                        });
                        _cargarDatos();
                      }
                    },
                    selectedColor: estado.color.withOpacity(0.2),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inDays > 0) {
      return '${diferencia.inDays} día${diferencia.inDays == 1 ? '' : 's'} atrás';
    } else if (diferencia.inHours > 0) {
      return '${diferencia.inHours} hora${diferencia.inHours == 1 ? '' : 's'} atrás';
    } else if (diferencia.inMinutes > 0) {
      return '${diferencia.inMinutes} minuto${diferencia.inMinutes == 1 ? '' : 's'} atrás';
    } else {
      return 'Hace un momento';
    }
  }
}
