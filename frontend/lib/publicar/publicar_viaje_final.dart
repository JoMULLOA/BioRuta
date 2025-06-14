import 'package:flutter/material.dart';
import '../models/direccion_sugerida.dart';

class PublicarViajeFinal extends StatefulWidget {
  final List<DireccionSugerida> ubicaciones;
  final DateTime fechaIda;
  final TimeOfDay horaIda;
  final DateTime? fechaVuelta;
  final TimeOfDay? horaVuelta;
  final bool viajeIdaYVuelta;
  final bool soloMujeres;
  final String flexibilidadSalida;
  
  const PublicarViajeFinal({
    super.key,
    required this.ubicaciones,
    required this.fechaIda,
    required this.horaIda,
    this.fechaVuelta,
    this.horaVuelta,
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

  @override
  void initState() {
    super.initState();
    _calcularPrecioEstimado();
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

  String _formatearHora(TimeOfDay hora) {
    return '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  void _publicarViaje() {
    // Los comentarios ahora son opcionales, se eliminó la validación

    // Aquí irían las variables que enviarías al backend
    Map<String, dynamic> datosViaje = {
      'ubicaciones': widget.ubicaciones.map((u) => {
        'nombre': u.displayName,
        'latitud': u.lat,
        'longitud': u.lon,
      }).toList(),
      'fechaIda': widget.fechaIda.toIso8601String(),
      'horaIda': '${widget.horaIda.hour}:${widget.horaIda.minute}',
      'fechaVuelta': widget.fechaVuelta?.toIso8601String(),
      'horaVuelta': widget.horaVuelta != null 
          ? '${widget.horaVuelta!.hour}:${widget.horaVuelta!.minute}' 
          : null,
      'viajeIdaYVuelta': widget.viajeIdaYVuelta,
      'soloMujeres': widget.soloMujeres,
      'flexibilidadSalida': widget.flexibilidadSalida,
      'precio': precio,
      'plazasDisponibles': plazasDisponibles,
      'comentarios': _comentariosController.text.trim(),
    };

    // Mostrar los datos en consola para debugging
    debugPrint('=== DATOS DEL VIAJE PARA BACKEND ===');
    debugPrint(datosViaje.toString());
    debugPrint('==================================');

    // Aquí harías la llamada al backend
    // Por ahora, mostrar confirmación
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 ¡Viaje publicado exitosamente!'),
          backgroundColor: Color(0xFF854937),
          duration: Duration(seconds: 3),
        ),
      );
    }

    // Regresar a la pantalla principal después de un delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.pushReplacementNamed(context, '/inicio');
      }
    });
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
                    '${_formatearFecha(widget.fechaIda)} a las ${_formatearHora(widget.horaIda)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
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
                        onPressed: plazasDisponibles < 5 
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
          onPressed: _publicarViaje,
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