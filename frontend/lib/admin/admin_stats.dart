import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/confGlobal.dart';
import '../services/estadisticas_service.dart';

class AdminStats extends StatefulWidget {
  const AdminStats({super.key});

  @override
  State<AdminStats> createState() => _AdminStatsState();
}

class _AdminStatsState extends State<AdminStats> with TickerProviderStateMixin {
  // Variables para almacenar estadísticas
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Variables para métricas específicas
  int _totalUsuarios = 0;
  int _totalViajes = 0;
  int _viajesActivos = 0;
  int _viajesCompletados = 0;
  int _totalVehiculos = 0;
  List<Map<String, dynamic>> _usuariosPorPuntuacion = [];
  List<Map<String, dynamic>> _viajesPorMes = [];
  List<Map<String, dynamic>> _clasificacionUsuarios = [];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Cargar todas las estadísticas en paralelo
      final results = await Future.wait([
        EstadisticasService.obtenerEstadisticasGenerales(),
        EstadisticasService.obtenerDistribucionPuntuaciones(),
        EstadisticasService.obtenerViajesPorMes(),
        EstadisticasService.obtenerClasificacionUsuarios(),
      ]);

      final estadisticasGenerales = results[0] as Map<String, dynamic>;
      final distribucionPuntuaciones = results[1] as List<Map<String, dynamic>>;
      final viajesPorMes = results[2] as List<Map<String, dynamic>>;
      final clasificacionUsuarios = results[3] as List<Map<String, dynamic>>;

      setState(() {
        // Extraer datos de estadísticas generales
        _totalUsuarios = estadisticasGenerales['usuarios']?['total'] ?? 0;
        _totalViajes = estadisticasGenerales['viajes']?['total'] ?? 0;
        _viajesActivos = estadisticasGenerales['viajes']?['activos'] ?? 0;
        _viajesCompletados = estadisticasGenerales['viajes']?['completados'] ?? 0;
        _totalVehiculos = estadisticasGenerales['vehiculos']?['total'] ?? 0;

        // Procesar distribución de puntuaciones
        _usuariosPorPuntuacion = distribucionPuntuaciones.map((item) {
          return {
            'puntuacion': item['puntuacion'],
            'cantidad': item['cantidad'],
            'color': _getColorFromHex(item['color']),
          };
        }).toList();

        // Procesar viajes por mes
        _viajesPorMes = viajesPorMes;

        // Procesar clasificación de usuarios
        _clasificacionUsuarios = clasificacionUsuarios;

        _isLoading = false;
      });
    } catch (error) {
      print('Error al cargar estadísticas: $error');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar las estadísticas: ${error.toString()}';
      });
    }
  }

  Color _getColorFromHex(String hexColor) {
    try {
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      // Color por defecto si hay error
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fondo = Color(0xFFF8F2EF);
    final Color primario = Color(0xFF854937);
    final Color secundario = Color(0xFF8D4F3A);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: primario,
        elevation: 0,
        title: const Text(
          'Estadísticas del Sistema',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualizar estadísticas',
            onPressed: _loadStatistics,
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
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando estadísticas reales...',
                    style: TextStyle(
                      color: primario,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadStatistics,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primario,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStatistics,
                  color: primario,
                  backgroundColor: fondo,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Banner indicando datos reales
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Mostrando datos reales del sistema',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Métricas principales en tarjetas
                        _buildMetricasGenerales(primario, secundario),
                        
                        const SizedBox(height: 24),
                        
                        // Gráfico de distribución de puntuaciones
                        if (_usuariosPorPuntuacion.isNotEmpty)
                          _buildPuntuacionChart(primario, secundario),
                        
                        const SizedBox(height: 24),
                        
                        // Gráfico de viajes por mes
                        if (_viajesPorMes.isNotEmpty)
                          _buildViajesPorMesChart(primario, secundario),
                        
                        const SizedBox(height: 24),
                        
                        // Gráfico de clasificaciones de usuarios
                        if (_clasificacionUsuarios.isNotEmpty)
                          _buildClasificacionChart(primario, secundario),
                        
                        const SizedBox(height: 24),
                        
                        // Estadísticas adicionales
                        _buildEstadisticasAdicionales(primario, secundario),
                        
                        // Espacio adicional al final para evitar que el último elemento quede pegado al borde
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMetricasGenerales(Color primario, Color secundario) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Métricas Generales',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primario,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.8, // Aumentar para dar más espacio horizontal
          children: [
            _buildMetricCard(
              'Total Usuarios',
              _totalUsuarios.toString(),
              Icons.people,
              Colors.blue,
            ),
            _buildMetricCard(
              'Total Viajes',
              _totalViajes.toString(),
              Icons.drive_eta,
              Colors.green,
            ),
            _buildMetricCard(
              'Viajes Activos',
              _viajesActivos.toString(),
              Icons.schedule,
              Colors.orange,
            ),
            _buildMetricCard(
              'Vehículos Registrados',
              _totalVehiculos.toString(),
              Icons.directions_car,
              Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12), // Reducir padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Ajustar al contenido
          children: [
            Flexible(
              child: Icon(icon, size: 28, color: color), // Reducir tamaño del ícono
            ),
            const SizedBox(height: 6), // Reducir espacio
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 22, // Reducir tamaño de fuente
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2, // Permitir 2 líneas
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10, // Reducir tamaño de fuente
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuntuacionChart(Color primario, Color secundario) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: primario, size: 24),
              const SizedBox(width: 8),
              Text(
                'Distribución de Puntuaciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primario,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: _usuariosPorPuntuacion.map((data) {
                  return PieChartSectionData(
                    value: data['cantidad'].toDouble(),
                    title: '${data['puntuacion']}\n${data['cantidad']}',
                    color: data['color'],
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: _usuariosPorPuntuacion.map((data) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: data['color'],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${data['puntuacion']} puntos (${data['cantidad']})',
                    style: TextStyle(
                      fontSize: 12,
                      color: secundario,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildViajesPorMesChart(Color primario, Color secundario) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: primario, size: 24),
              const SizedBox(width: 8),
              Text(
                'Viajes por Mes (2025)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primario,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < _viajesPorMes.length) {
                          return Text(
                            _viajesPorMes[value.toInt()]['mes'],
                            style: TextStyle(color: secundario, fontSize: 12),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(color: secundario, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _viajesPorMes.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value['viajes'].toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    gradient: LinearGradient(colors: [primario, secundario]),
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          primario.withOpacity(0.3),
                          secundario.withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: primario,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClasificacionChart(Color primario, Color secundario) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment, color: primario, size: 24),
              const SizedBox(width: 8),
              Text(
                'Clasificación de Usuarios',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primario,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < _clasificacionUsuarios.length) {
                          return Text(
                            _clasificacionUsuarios[value.toInt()]['rango'],
                            style: TextStyle(color: secundario, fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(color: secundario, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _clasificacionUsuarios.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value['cantidad'].toDouble(),
                        gradient: LinearGradient(
                          colors: [primario, secundario],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticasAdicionales(Color primario, Color secundario) {
    final double promedioViajes = _totalViajes / _totalUsuarios;
    final double tasaCompletacion = (_viajesCompletados / _totalViajes) * 100;
    final double vehiculosPorUsuario = _totalVehiculos / _totalUsuarios;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: primario, size: 24),
              const SizedBox(width: 8),
              Text(
                'Análisis Avanzado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primario,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAnalysisItem(
            'Promedio de viajes por usuario',
            '${promedioViajes.toStringAsFixed(1)} viajes',
            Icons.person_outline,
            primario,
          ),
          _buildAnalysisItem(
            'Tasa de completación de viajes',
            '${tasaCompletacion.toStringAsFixed(1)}%',
            Icons.check_circle_outline,
            Colors.green,
          ),
          _buildAnalysisItem(
            'Vehículos por usuario',
            '${vehiculosPorUsuario.toStringAsFixed(2)} vehículos',
            Icons.directions_car_outlined,
            Colors.blue,
          ),
          _buildAnalysisItem(
            'Viajes activos vs completados',
            '${_viajesActivos} vs ${_viajesCompletados}',
            Icons.compare_arrows,
            secundario,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(String title, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B3B2D),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}