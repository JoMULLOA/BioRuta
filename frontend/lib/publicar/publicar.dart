import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/navbar_con_sos_dinamico.dart';
import '../services/user_service.dart';
import '../models/viaje_model.dart';
import 'publicar_viaje_paso1.dart';
import '../providers/theme_provider.dart';
import '../config/app_colors.dart';

class PublicarPage extends StatefulWidget {
  const PublicarPage({super.key});
  
  @override
  PublicarPageState createState() => PublicarPageState();
}

class PublicarPageState extends State<PublicarPage> {
  int _selectedIndex = 2;
  bool _cargandoVehiculos = true;
  List<VehiculoViaje> _vehiculosDisponibles = [];
  String? _mensajeError;

  @override
  void initState() {
    super.initState();
    _verificarVehiculos();
  }

  Future<void> _verificarVehiculos() async {
    try {
      setState(() {
        _cargandoVehiculos = true;
        _mensajeError = null;
      });

      print('🚗 Verificando vehículos del usuario...');
      final vehiculosData = await UserService.obtenerMisVehiculos();
      final vehiculos = vehiculosData.map((v) => VehiculoViaje.fromJson(v)).toList();
      
      print('✅ Vehículos encontrados: ${vehiculos.length}');
      
      setState(() {
        _vehiculosDisponibles = vehiculos;
        _cargandoVehiculos = false;
      });
      
    } catch (e) {
      print('❌ Error verificando vehículos: $e');
      
      setState(() {
        _cargandoVehiculos = false;
        _mensajeError = 'Error al verificar vehículos: ${e.toString()}';
      });

      // Si es un error de autenticación, redirigir al login
      if (e.toString().contains('Sesión expirada') || 
          e.toString().contains('autenticación') ||
          e.toString().contains('inicia sesión')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tu sesión ha expirado. Redirigiendo al login...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Esperar un momento antes de redirigir
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login', 
                (Route<dynamic> route) => false,
              );
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
        final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: const Text('Publicar Viaje'),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/mapa');
                }
              },
            ),
          ),
          body: _buildBody(primaryColor, textColor, surfaceColor),
          bottomNavigationBar: NavbarConSOSDinamico(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == _selectedIndex) return;

          setState(() {
            _selectedIndex = index;
          });

          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/mis-viajes');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/mapa');
              break;
            case 2:
              break; // Ya estamos en Publicar
            case 3:
              Navigator.pushReplacementNamed(context, '/chat');
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/ranking');
              break;
            case 5:
              Navigator.pushReplacementNamed(context, '/perfil');
              break;
          }
        },
          ),
        );
      },
    );
  }

  Widget _buildBody(Color primaryColor, Color textColor, Color surfaceColor) {
    if (_cargandoVehiculos) {
      return _buildLoadingState(primaryColor);
    } else if (_mensajeError != null) {
      return _buildErrorState(primaryColor, textColor);
    } else if (_vehiculosDisponibles.isEmpty) {
      return _buildNoVehiclesState(primaryColor, textColor);
    } else {
      return _buildPublishOptions(primaryColor, textColor, surfaceColor);
    }
  }

  Widget _buildLoadingState(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Verificando vehículos...',
            style: TextStyle(
              fontSize: 16,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color primaryColor, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Error al verificar vehículos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _mensajeError ?? 'Error desconocido',
              style: TextStyle(
                fontSize: 16,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _verificarVehiculos,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoVehiclesState(Color primaryColor, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 30),
            Text(
              '¡Necesitas un vehículo!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Para publicar viajes necesitas tener al menos un vehículo registrado.',
              style: TextStyle(
                fontSize: 16,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            // Botón principal - Agregar vehículo
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Ve a tu perfil para agregar un vehículo'),
                    backgroundColor: primaryColor,
                    duration: const Duration(seconds: 3),
                  ),
                );
                Navigator.pushReplacementNamed(context, '/perfil');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Agregar Vehículo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Botón secundario - Recargar
            OutlinedButton(
              onPressed: _verificarVehiculos,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Verificar nuevamente',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishOptions(Color primaryColor, Color textColor, Color surfaceColor) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          
          // Título principal
          Text(
            '¡Comparte tu viaje!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          
          const SizedBox(height: 15),
          
          Text(
            'Conecta con otros viajeros y ahorra en tus trayectos',
            style: TextStyle(
              fontSize: 16,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 40),
          
          // Información de vehículos disponibles
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tienes ${_vehiculosDisponibles.length} vehículo${_vehiculosDisponibles.length > 1 ? 's' : ''} registrado${_vehiculosDisponibles.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Opciones de publicación
          _buildPublishOption(
            context,
            primaryColor: primaryColor,
            textColor: textColor,
            surfaceColor: surfaceColor,
            icon: Icons.location_on,
            title: 'Publicar un viaje',
            description: 'Comparte tu ruta y ahorra combustible',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PublicarViajePaso1(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPublishOption(BuildContext context, {
    required Color primaryColor,
    required Color textColor,
    required Color surfaceColor,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF070505).withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: primaryColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}