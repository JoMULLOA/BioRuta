import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/token_manager.dart';
import '../config/confGlobal.dart';
import 'agregar_vehiculo.dart';
import 'editar_vehiculo.dart';

class MisVehiculosPage extends StatefulWidget {
  const MisVehiculosPage({super.key});

  @override
  State<MisVehiculosPage> createState() => _MisVehiculosPageState();
}

class _MisVehiculosPageState extends State<MisVehiculosPage> {
  List<Map<String, dynamic>> _vehiculos = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadVehiculos();
  }

  Future<void> _loadVehiculos() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No se pudo obtener token de autenticación';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${confGlobal.baseUrl}/user/mis-vehiculos'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _vehiculos = List<Map<String, dynamic>>.from(data['data']);
            _isLoading = false;
          });
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = data['message'] ?? 'Error al cargar vehículos';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error del servidor (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToAgregarVehiculo() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AgregarVehiculoPage()),
    );
    
    // Si se agregó un vehículo, recargar la lista
    if (result == true) {
      _loadVehiculos();
    }
  }

  Future<void> _navigateToEditarVehiculo(Map<String, dynamic> vehiculo) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarVehiculoPage(vehiculo: vehiculo),
      ),
    );
    
    // Si se editó o eliminó el vehículo, recargar la lista
    if (result == true) {
      _loadVehiculos();
    }
  }

  Future<void> _eliminarVehiculo(Map<String, dynamic> vehiculo) async {
    // Mostrar diálogo de confirmación
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Eliminar Vehículo'),
          content: Text(
            '¿Estás seguro de que quieres eliminar el vehículo ${vehiculo['patente']}?\n\nEsta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Eliminar'),
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
          builder: (BuildContext context) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B3B2D)),
              ),
            );
          },
        );

        final headers = await TokenManager.getAuthHeaders();
        if (headers == null) {
          Navigator.of(context).pop(); // Cerrar indicador de carga
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: No se pudo obtener token de autenticación'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final response = await http.delete(
          Uri.parse('${confGlobal.baseUrl}/vehiculos/${vehiculo['patente']}'),
          headers: headers,
        );

        Navigator.of(context).pop(); // Cerrar indicador de carga

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            // Recargar la lista de vehículos
            _loadVehiculos();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Vehículo eliminado exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? 'Error al eliminar vehículo'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error del servidor (${response.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        Navigator.of(context).pop(); // Cerrar indicador de carga si existe
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
        return 'Auto';
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
        return 'Bencina';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fondo = Color(0xFFF8F2EF);
    final Color primario = Color(0xFF6B3B2D);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8D4F3A),
        elevation: 0,
        title: Text('Mis Vehículos', style: TextStyle(color: fondo)),
        iconTheme: IconThemeData(color: fondo),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAgregarVehiculo,
        backgroundColor: primario,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Agregar Vehículo',
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B3B2D)),
        ),
      );
    }

    if (_hasError) {
      return Center(
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
              'Error al cargar vehículos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B3B2D),
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadVehiculos,
              icon: Icon(Icons.refresh),
              label: Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6B3B2D),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_vehiculos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No tienes vehículos registrados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B3B2D),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Agrega tu primer vehículo para poder ofrecer viajes',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToAgregarVehiculo,
              icon: Icon(Icons.add),
              label: Text('Agregar Vehículo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6B3B2D),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVehiculos,
      color: Color(0xFF6B3B2D),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _vehiculos.length,
        itemBuilder: (context, index) {
          final vehiculo = _vehiculos[index];
          return _buildVehiculoCard(vehiculo);
        },
      ),
    );
  }

  Widget _buildVehiculoCard(Map<String, dynamic> vehiculo) {
    final Color primario = Color(0xFF6B3B2D);
    final Color secundario = Color(0xFF8D4F3A);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
          // Header con patente y botones de acción
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primario,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  vehiculo['patente'] ?? 'Sin patente',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _navigateToEditarVehiculo(vehiculo),
                    icon: Icon(Icons.edit, color: secundario),
                    tooltip: 'Editar vehículo',
                  ),
                  IconButton(
                    onPressed: () => _eliminarVehiculo(vehiculo),
                    icon: Icon(Icons.delete, color: Colors.red[600]),
                    tooltip: 'Eliminar vehículo',
                  ),
                ],
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Información del vehículo
          _buildInfoRow(Icons.category, 'Tipo', _getNombreTipo(vehiculo['tipo'] ?? 'otro')),
          SizedBox(height: 12),
          _buildInfoRow(Icons.directions_car, 'Modelo', vehiculo['modeloCompleto'] ?? vehiculo['modelo'] ?? 'No especificado'),
          SizedBox(height: 12),
          _buildInfoRow(Icons.palette, 'Color', vehiculo['color'] ?? 'No especificado'),
          SizedBox(height: 12),
          _buildInfoRow(Icons.local_gas_station, 'Combustible', _getNombreCombustible(vehiculo['tipoCombustible'] ?? 'bencina')),
          SizedBox(height: 12),
          _buildInfoRow(Icons.people, 'Asientos', '${vehiculo['nro_asientos'] ?? 0} asientos'),
          SizedBox(height: 12),
          _buildInfoRow(Icons.description, 'Documentación', vehiculo['documentacion'] ?? 'No especificado'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final Color primario = Color(0xFF6B3B2D);
    
    return Row(
      children: [
        Icon(icon, color: primario, size: 20),
        SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primario,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
