import 'package:flutter/material.dart';
import '../models/direccion_sugerida.dart';
import '../mapa/mapa_seleccion_simple.dart';
import '../services/viaje_service.dart';
import 'publicar_viaje_paso2.dart';

class PublicarViajePaso1 extends StatefulWidget {
  const PublicarViajePaso1({super.key});

  @override
  State<PublicarViajePaso1> createState() => _PublicarViajePaso1State();
}

class _PublicarViajePaso1State extends State<PublicarViajePaso1> {
  List<DireccionSugerida> ubicaciones = [];
  String? origenTexto;
  String? destinoTexto;
  
  // Variables para el cálculo de precio
  bool calculandoPrecio = false;
  double? kilometrosRuta;
  Map<String, dynamic>? infoPrecio;
  double? precioSugerido;

  Future<void> _seleccionarUbicacion(bool esOrigen) async {
    // Obtener origen seleccionado para calcular tiempo correcto cuando es destino
    DireccionSugerida? origenSeleccionado;
    if (!esOrigen) {
      // Es destino: buscar origen ya seleccionado
      origenSeleccionado = ubicaciones.where((u) => u.esOrigen == true).isNotEmpty
          ? ubicaciones.where((u) => u.esOrigen == true).first
          : null;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapaSeleccionPage(
          tituloSeleccion: esOrigen ? "Seleccionar Origen" : "Seleccionar Destino",
          esOrigen: esOrigen,
          origenSeleccionado: origenSeleccionado, // Pasar origen cuando es destino
        ),
      ),
    );

    if (result != null && result is DireccionSugerida) {
      setState(() {
        if (esOrigen) {
          origenTexto = result.displayName;
          // Reemplazar o agregar origen
          ubicaciones.removeWhere((u) => u.esOrigen == true);
          ubicaciones.insert(0, DireccionSugerida(
            displayName: result.displayName,
            lat: result.lat,
            lon: result.lon,
            esOrigen: true,
          ));
        } else {
          destinoTexto = result.displayName;
          // Reemplazar o agregar destino
          ubicaciones.removeWhere((u) => u.esOrigen == false);
          ubicaciones.add(DireccionSugerida(
            displayName: result.displayName,
            lat: result.lat,
            lon: result.lon,
            esOrigen: false,
          ));
        }
      });
      
      // Calcular precio automáticamente cuando tengamos origen y destino
      if (_puedeAvanzar) {
        _calcularPrecioRuta();
      }
    }
  }

  Future<void> _calcularPrecioRuta() async {
    if (ubicaciones.length < 2) return;
    
    setState(() {
      calculandoPrecio = true;
    });
    
    try {
      print('🔢 Calculando precio para la ruta seleccionada...');
      
      final origen = ubicaciones.first;
      final destino = ubicaciones.last;
      
      print('📍 Ruta: ${origen.displayName} → ${destino.displayName}');
      
      // Llamar al backend para obtener precio sugerido
      final resultado = await ViajeService.obtenerPrecioSugerido(
        origenLat: origen.lat,
        origenLon: origen.lon,
        destinoLat: destino.lat,
        destinoLon: destino.lon,
      );
      
      if (resultado['success'] == true && resultado['data'] != null) {
        final data = resultado['data'];
        
        print('✅ Precio calculado:');
        print('   Kilómetros: ${data['kilometros']} km');
        print('   Precio sugerido: \$${data['precioFinal']}');
        
        setState(() {
          kilometrosRuta = data['kilometros']?.toDouble() ?? 0.0;
          precioSugerido = data['precioFinal']?.toDouble() ?? 0.0;
          infoPrecio = {
            'kilometros': data['kilometros'],
            'precioBase': data['precioBase'],
            'precioFinal': data['precioFinal'],
            'precioPorKm': data['precioPorKm'],
            'desglose': data['desglose'],
          };
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('💰 Ruta calculada: ${data['kilometros']} km • \$${data['precioFinal']}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        print('❌ Error calculando precio: ${resultado['message']}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${resultado['message']}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error calculando precio: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        calculandoPrecio = false;
      });
    }
  }

  bool get _puedeAvanzar => origenTexto != null && destinoTexto != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: const Text('Paso 1: Ruta'),
        backgroundColor: const Color(0xFF854937),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicador de progreso
            _buildProgressIndicator(1),
            
            const SizedBox(height: 30),
            
            const Text(
              'Define tu ruta',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF854937),
              ),
            ),
            
            const SizedBox(height: 10),
            
            const Text(
              'Selecciona el punto de partida y destino de tu viaje',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B3B2D),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Origen
            _buildLocationCard(
              title: 'Punto de partida',
              icon: Icons.my_location,
              selectedLocation: origenTexto,
              placeholder: 'Seleccionar origen',
              onTap: () => _seleccionarUbicacion(true),
            ),
            
            const SizedBox(height: 20),
            
            // Icono de flecha
            const Center(
              child: Icon(
                Icons.arrow_downward,
                size: 30,
                color: Color(0xFF854937),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Destino
            _buildLocationCard(
              title: 'Destino',
              icon: Icons.place,
              selectedLocation: destinoTexto,
              placeholder: 'Seleccionar destino',
              onTap: () => _seleccionarUbicacion(false),
            ),
            
            const SizedBox(height: 20),
            
            // Información del precio calculado
            if (calculandoPrecio)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Calculando kilómetros y precio de la ruta...',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else if (kilometrosRuta != null && precioSugerido != null && infoPrecio != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.route, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${kilometrosRuta!.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF854937),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '\$${precioSugerido!.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Precio base: \$${infoPrecio!['precioBase']} (${infoPrecio!['precioPorKm']}/km)',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    if (infoPrecio!['desglose'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Incluye: combustible, desgaste y tiempo de conducción',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            
            const SizedBox(height: 40),
            
            // Botón siguiente
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _puedeAvanzar ? () {
                  Navigator.push(
                    context,                    MaterialPageRoute(
                      builder: (context) => PublicarViajePaso2(
                        ubicaciones: ubicaciones,
                        kilometrosRuta: kilometrosRuta,
                        precioSugerido: precioSugerido,
                        infoPrecio: infoPrecio,
                      ),
                    ),
                  );
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _puedeAvanzar 
                    ? const Color(0xFF854937) 
                    : Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Siguiente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int currentStep) {
    return Row(
      children: List.generate(4, (index) {
        final stepNumber = index + 1;
        final isActive = stepNumber <= currentStep;
        final isCurrent = stepNumber == currentStep;
        
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF854937) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(15),
                  border: isCurrent ? Border.all(color: const Color(0xFF854937), width: 3) : null,
                ),
                child: Center(
                  child: Text(
                    stepNumber.toString(),
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (index < 3)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isActive ? const Color(0xFF854937) : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required IconData icon,
    required String? selectedLocation,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedLocation != null 
              ? const Color(0xFF854937) 
              : Colors.grey.shade300,
          ),          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,              decoration: BoxDecoration(
                color: const Color(0xFF854937).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF854937),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF854937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedLocation ?? placeholder,
                    style: TextStyle(
                      fontSize: 16,
                      color: selectedLocation != null 
                        ? const Color(0xFF070505) 
                        : Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF854937),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}