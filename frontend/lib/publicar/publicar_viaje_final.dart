import 'package:flutter/material.dart';
import '../models/direccion_sugerida.dart';
import '../services/viaje_service.dart';
import '../services/user_service.dart';
import '../models/viaje_model.dart';

class PublicarViajeFinal extends StatefulWidget {
  final List<DireccionSugerida> ubicaciones;
  final DateTime fechaHoraIda;
  final DateTime? fechaHoraVuelta;
  final bool viajeIdaYVuelta;
  final bool soloMujeres;
  final String flexibilidadSalida;
  
  const PublicarViajeFinal({
    super.key,
    required this.ubicaciones,
    required this.fechaHoraIda,
    this.fechaHoraVuelta,
    required this.viajeIdaYVuelta,
    required this.soloMujeres,
    required this.flexibilidadSalida,
  });

  @override
  State<PublicarViajeFinal> createState() => _PublicarViajeFinalState();
}

class _PublicarViajeFinalState extends State<PublicarViajeFinal> {
  final TextEditingController _comentariosController = TextEditingController();
  double precio = 0.0;
  int plazasDisponibles = 3;
  VehiculoViaje? vehiculoSeleccionado;
  List<VehiculoViaje> vehiculosDisponibles = [];
  bool cargandoVehiculos = true;

  @override
  void initState() {
    super.initState();
    _calcularPrecioEstimado();
    _cargarVehiculos();
  }

  Future<void> _cargarVehiculos() async {
    try {
      setState(() {
        cargandoVehiculos = true;
      });

      print('🚗 Cargando vehículos del usuario...');
      final vehiculosData = await UserService.obtenerMisVehiculos();
      final vehiculos = vehiculosData.map((v) => VehiculoViaje.fromJson(v)).toList();
      
      print('✅ Vehículos cargados: ${vehiculos.length}');
      
      setState(() {
        vehiculosDisponibles = vehiculos;
        if (vehiculos.isNotEmpty) {
          vehiculoSeleccionado = vehiculos.first;
          plazasDisponibles = vehiculos.first.nroAsientos - 1; // Conductor no cuenta
        }
        cargandoVehiculos = false;
      });
      
      if (vehiculos.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No tienes vehículos registrados. Agrega uno en tu perfil.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error cargando vehículos: $e');
      
      setState(() {
        cargandoVehiculos = false;
      });
      
      if (mounted) {
        String mensajeError = 'Error al cargar vehículos';
        
        if (e.toString().contains('Connection refused')) {
          mensajeError = 'No se puede conectar al servidor';
        } else if (e.toString().contains('401') || e.toString().contains('No autorizado')) {
          mensajeError = 'Error de autenticación. Reinicia sesión';
        } else {
          mensajeError = 'Error: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $mensajeError'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _calcularPrecioEstimado() {
    // Simulación del cálculo de precio basado en distancia
    // En una implementación real, esto calcularía la distancia real
    double distanciaEstimada = _calcularDistanciaTotal();
    setState(() {
      precio = (distanciaEstimada * 25).roundToDouble(); // 25 pesos por km como base
    });
  }

  double _calcularDistanciaTotal() {
    if (widget.ubicaciones.length < 2) return 0.0;
    
    // Simulación simple - en realidad usarías una API de routing
    double distanciaTotal = 0.0;
    for (int i = 0; i < widget.ubicaciones.length - 1; i++) {
      double lat1 = widget.ubicaciones[i].lat;
      double lon1 = widget.ubicaciones[i].lon;
      double lat2 = widget.ubicaciones[i + 1].lat;
      double lon2 = widget.ubicaciones[i + 1].lon;
      
      // Fórmula simple de distancia euclidiana (no es precisa para geografía real)
      double distancia = ((lat2 - lat1) * (lat2 - lat1) + (lon2 - lon1) * (lon2 - lon1)) * 100;
      distanciaTotal += distancia;
    }
    
    return distanciaTotal.clamp(50, 500); // Entre 50 y 500 km estimados
  }

  String _formatearHora(DateTime fechaHora) {
    return '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}';
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  Future<void> _publicarViaje() async {
    if (vehiculoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar un vehículo')),
      );
      return;
    }

    if (widget.ubicaciones.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes especificar origen y destino')),
      );
      return;
    }

    try {
      // Preparar ubicaciones - usar los nombres exactos que espera el backend
      final ubicaciones = widget.ubicaciones.map((u) => {
        'displayName': u.displayName,  // Cambiar de 'nombre' a 'displayName'
        'lat': u.lat,                  // Cambiar de 'latitud' a 'lat'
        'lon': u.lon,                  // Cambiar de 'longitud' a 'lon'
        'esOrigen': u.esOrigen,
      }).toList();

      print('📍 Ubicaciones a enviar: $ubicaciones');
      print('📅 Fecha y hora ida: ${widget.fechaHoraIda}');
      if (widget.viajeIdaYVuelta && widget.fechaHoraVuelta != null) {
        print('� Fecha y hora vuelta: ${widget.fechaHoraVuelta}');
      }

      final resultado = await ViajeService.crearViaje(
        ubicaciones: ubicaciones,
        fechaHoraIda: widget.fechaHoraIda.toIso8601String(),
        fechaHoraVuelta: widget.fechaHoraVuelta?.toIso8601String(),
        viajeIdaYVuelta: widget.viajeIdaYVuelta,
        maxPasajeros: vehiculoSeleccionado!.nroAsientos - 1, // Sin contar conductor
        soloMujeres: widget.soloMujeres,
        flexibilidadSalida: widget.flexibilidadSalida,
        precio: precio,
        plazasDisponibles: plazasDisponibles,
        comentarios: _comentariosController.text.trim(), // Enviar string vacío en lugar de null
        vehiculoPatente: vehiculoSeleccionado!.patente,
      );

      if (mounted) {
        if (resultado['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Viaje publicado exitosamente!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Volver al inicio o mapa
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/mapa', 
            (Route<dynamic> route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${resultado['message'] ?? 'Error al publicar viaje'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error publicando viaje: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: const Text('Publicar'),
        backgroundColor: const Color(0xFF854937),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicador de progreso
            _buildProgressIndicator(4),
            
            const SizedBox(height: 30),
            
            const Text(
              'Finalizar publicación',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF854937),
              ),
            ),
            
            const SizedBox(height: 10),
            
            const Text(
              'Revisa los detalles y publica tu viaje',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B3B2D),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              'Aportación por pasajero',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF070505),
              ),
            ),
            const SizedBox(height: 20),
            
            // Resumen del viaje
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDCAB6)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF070505).withValues(alpha: 0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${widget.ubicaciones.first.displayName} → ${widget.ubicaciones.last.displayName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF070505),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$ ${precio.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF854937),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatearFecha(widget.fechaHoraIda)} a las ${_formatearHora(widget.fechaHoraIda)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Selector de vehículo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDCAB6)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF070505).withValues(alpha: 0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seleccionar vehículo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF070505),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (cargandoVehiculos)
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF854937)),
                      ),
                    )
                  else if (vehiculosDisponibles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No tienes vehículos registrados. Ve a tu perfil para agregar uno.',
                              style: TextStyle(color: Colors.orange, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<VehiculoViaje>(
                      value: vehiculoSeleccionado,
                      decoration: InputDecoration(
                        hintText: 'Selecciona un vehículo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFEDCAB6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFEDCAB6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF854937)),
                        ),
                      ),
                      items: vehiculosDisponibles.map((vehiculo) {
                        return DropdownMenuItem<VehiculoViaje>(
                          value: vehiculo,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                vehiculo.modelo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${vehiculo.patente} • ${vehiculo.color} • ${vehiculo.nroAsientos} asientos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (VehiculoViaje? newValue) {
                        setState(() {
                          vehiculoSeleccionado = newValue;
                          if (newValue != null) {
                            plazasDisponibles = newValue.nroAsientos - 1; // Sin contar conductor
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Selector de plazas disponibles
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDCAB6)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF070505).withValues(alpha: 0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plazas disponibles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF070505),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: plazasDisponibles > 1 
                            ? () => setState(() => plazasDisponibles--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: const Color(0xFF854937),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF854937)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          plazasDisponibles.toString(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF854937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        onPressed: (vehiculoSeleccionado != null && plazasDisponibles < (vehiculoSeleccionado!.nroAsientos - 1))
                            ? () => setState(() => plazasDisponibles++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: const Color(0xFF854937),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            const Text(
              'Comentario de viaje',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF070505),
              ),
            ),
            const SizedBox(height: 12),
            
            // Campo de comentarios
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDCAB6)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF070505).withValues(alpha: 0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _comentariosController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Añade información útil a la que los pasajeros puedan referirse durante el viaje',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF070505),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF070505).withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: (vehiculoSeleccionado != null && !cargandoVehiculos) ? _publicarViaje : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF854937),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Publicar viaje',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
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

  @override
  void dispose() {
    _comentariosController.dispose();
    super.dispose();
  }
}