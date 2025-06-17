import 'package:flutter/material.dart';
import '../models/direccion_sugerida.dart';
import '../mapa/mapa_seleccion_simple.dart';
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

  Future<void> _seleccionarUbicacion(bool esOrigen) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapaSeleccionPage(
          tituloSeleccion: esOrigen ? "Seleccionar Origen" : "Seleccionar Destino",
          esOrigen: esOrigen,
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