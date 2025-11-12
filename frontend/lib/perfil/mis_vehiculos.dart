import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/theme_provider.dart';
import '../config/app_colors.dart';
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
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final primaryColor = themeProvider.isDarkMode 
            ? AppColors.primaryDark 
            : AppColors.primaryLight;
        final backgroundColor = themeProvider.isDarkMode 
            ? AppColors.darkBackground 
            : AppColors.lightBackground;
        final surfaceColor = themeProvider.isDarkMode 
            ? AppColors.darkSurface 
            : AppColors.lightSurface;
        final textColor = themeProvider.isDarkMode 
            ? AppColors.darkText 
            : AppColors.lightText;

        return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text('Mis Vehículos', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _buildBody(primaryColor, backgroundColor, surfaceColor, textColor),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAgregarVehiculo,
        backgroundColor: primaryColor,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Agregar Vehículo',
      ),
    );
      }
    );
  }

  Widget _buildBody(Color primaryColor, Color backgroundColor, Color surfaceColor, Color textColor) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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
                color: textColor,
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
                backgroundColor: primaryColor,
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
                color: textColor,
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
                backgroundColor: primaryColor,
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
      color: primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _vehiculos.length,
        itemBuilder: (context, index) {
          final vehiculo = _vehiculos[index];
          return _buildVehiculoCard(vehiculo, primaryColor, backgroundColor, surfaceColor, textColor);
        },
      ),
    );
  }

  Widget _buildVehiculoCard(Map<String, dynamic> vehiculo, Color primaryColor, Color backgroundColor, Color surfaceColor, Color textColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
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
                  color: primaryColor,
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
                    icon: Icon(Icons.edit, color: primaryColor),
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
          _buildInfoRow(Icons.category, 'Tipo', _getNombreTipo(vehiculo['tipo'] ?? 'otro'), primaryColor, textColor),
          SizedBox(height: 12),
          _buildInfoRow(Icons.directions_car, 'Modelo', vehiculo['modeloCompleto'] ?? vehiculo['modelo'] ?? 'No especificado', primaryColor, textColor),
          SizedBox(height: 12),
          _buildInfoRow(Icons.palette, 'Color', vehiculo['color'] ?? 'No especificado', primaryColor, textColor),
          SizedBox(height: 12),
          _buildInfoRow(Icons.local_gas_station, 'Combustible', _getNombreCombustible(vehiculo['tipoCombustible'] ?? 'bencina'), primaryColor, textColor),
          SizedBox(height: 12),
          _buildInfoRow(Icons.people, 'Asientos', '${vehiculo['nro_asientos'] ?? 0} asientos', primaryColor, textColor),
          SizedBox(height: 12),
          _buildInfoRow(Icons.description, 'Documentación', vehiculo['documentacion'] ?? 'No especificado', primaryColor, textColor),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color primaryColor, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryColor,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
