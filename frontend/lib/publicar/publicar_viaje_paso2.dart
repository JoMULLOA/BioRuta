import "package:flutter/material.dart";
import "../models/direccion_sugerida.dart";
import "../services/viaje_service.dart";
import "../utils/viaje_validator.dart";
import "publicar_viaje_paso3.dart";

class PublicarViajePaso2 extends StatefulWidget {
  final List<DireccionSugerida> ubicaciones;

  const PublicarViajePaso2({
    super.key,
    required this.ubicaciones, Map<String, dynamic>? infoPrecio, double? precioSugerido, double? kilometrosRuta,
  });

  @override
  State<PublicarViajePaso2> createState() => _PublicarViajePaso2State();
}

class _PublicarViajePaso2State extends State<PublicarViajePaso2> {
  DateTime? _fechaHoraIda;
  DateTime? _fechaHoraVuelta;
  bool _viajeIdaYVuelta = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: const Text("Paso 2: Fecha y Hora"),
        backgroundColor: const Color(0xFF854937),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressIndicator(2),
              const SizedBox(height: 30),
              const Text("Programa tu viaje", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF854937))),
              const SizedBox(height: 10),
              const Text("Selecciona cuándo quieres realizar tu viaje", style: TextStyle(fontSize: 16, color: Color(0xFF6B3B2D))),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Tipo de viaje", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF854937))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text("Solo ida", style: TextStyle(fontSize: 14)),
                            value: false,
                            groupValue: _viajeIdaYVuelta,
                            activeColor: const Color(0xFF854937),
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) {
                              setState(() {
                                _viajeIdaYVuelta = value!;
                                if (!_viajeIdaYVuelta) {
                                  _fechaHoraVuelta = null;
                                }
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text("Ida y vuelta", style: TextStyle(fontSize: 14)),
                            value: true,
                            groupValue: _viajeIdaYVuelta,
                            activeColor: const Color(0xFF854937),
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) {
                              setState(() {
                                _viajeIdaYVuelta = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildDateTimeCard(
                title: "Viaje de ida", 
                icon: Icons.flight_takeoff, 
                fechaHora: _fechaHoraIda, 
                onSelectDateTime: () => _seleccionarFechaHora(true)
              ),
              const SizedBox(height: 20),
              if (_viajeIdaYVuelta) _buildDateTimeCard(
                title: "Viaje de vuelta", 
                icon: Icons.flight_land, 
                fechaHora: _fechaHoraVuelta, 
                onSelectDateTime: () => _seleccionarFechaHora(false)
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _puedeAvanzar ? _continuarPaso3 : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _puedeAvanzar ? const Color(0xFF854937) : Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Siguiente", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
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
                child: Center(child: Text(stepNumber.toString(), style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold))),
              ),
              if (index < 3) Expanded(child: Container(height: 2, color: isActive ? const Color(0xFF854937) : Colors.grey.shade300)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDateTimeCard({
    required String title, 
    required IconData icon, 
    required DateTime? fechaHora, 
    required VoidCallback onSelectDateTime
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF854937).withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(20)
                ),
                child: Icon(icon, color: const Color(0xFF854937)),
              ),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF854937))),
            ],
          ),
          const SizedBox(height: 16),
          // Un solo botón para seleccionar fecha y hora
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSelectDateTime,
              icon: const Icon(Icons.calendar_today, size: 20),
              label: Text(
                fechaHora != null 
                  ? "${fechaHora.day}/${fechaHora.month}/${fechaHora.year} a las ${fechaHora.hour.toString().padLeft(2, "0")}:${fechaHora.minute.toString().padLeft(2, "0")}"
                  : "Seleccionar fecha y hora",
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: fechaHora != null ? const Color(0xFF854937) : Colors.grey.shade300,
                foregroundColor: fechaHora != null ? Colors.white : Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
          if (fechaHora != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    "Fecha y hora confirmadas",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool get _puedeAvanzar {
    if (_fechaHoraIda == null) return false;
    if (_viajeIdaYVuelta && _fechaHoraVuelta == null) return false;
    return true;
  }

  Future<void> _seleccionarFechaHora(bool esIda) async {
    // Primero seleccionar la fecha
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Selecciona la fecha del viaje',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF854937)),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return; // Usuario canceló la selección de fecha

    // Determinar la hora mínima basada en si es hoy o un día futuro
    final DateTime now = DateTime.now();
    final bool isToday = pickedDate.year == now.year && 
                        pickedDate.month == now.month && 
                        pickedDate.day == now.day;
    
    // Si es hoy, la hora mínima es la hora actual + 1 hora
    // Si es un día futuro, puede seleccionar cualquier hora
    TimeOfDay initialTime;
    if (isToday) {
      final nextHour = now.add(const Duration(hours: 1));
      initialTime = TimeOfDay(hour: nextHour.hour, minute: 0);
    } else {
      initialTime = const TimeOfDay(hour: 8, minute: 0); // 8:00 AM por defecto
    }

    // Ahora seleccionar la hora
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Selecciona la hora del viaje',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF854937)),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return; // Usuario canceló la selección de hora

    // Crear la fecha y hora combinada
    final DateTime combinedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Validar que no sea una hora pasada si es hoy
    if (isToday && combinedDateTime.isBefore(now.add(const Duration(minutes: 30)))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Selecciona una hora al menos 30 minutos en el futuro'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // NUEVA VALIDACIÓN: Verificar solapamiento si es viaje de vuelta
    if (!esIda && _fechaHoraIda != null) {
      try {
        final origen = widget.ubicaciones.firstWhere((u) => u.esOrigen == true);
        final destino = widget.ubicaciones.firstWhere((u) => u.esOrigen != true);
        
        final validacion = await ViajeService.validarPublicacionViaje(
          fechaHoraIda: _fechaHoraIda!,
          fechaHoraVuelta: combinedDateTime,
          origenLat: origen.lat,
          origenLng: origen.lon,
          destinoLat: destino.lat,
          destinoLng: destino.lon,
        );
        
        if (validacion['success'] != true) {
          if (mounted) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('⚠️ Conflicto con Viaje de Vuelta'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(validacion['message']),
                    if (validacion['duracionEstimada'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Duración estimada: ${ViajeValidator.formatearDuracion(validacion['duracionEstimada'])}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            );
          }
          return; // No actualizar la fecha si hay conflicto
        }
      } catch (e) {
        // En caso de error en la validación, mostrar advertencia pero permitir continuar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ No se pudo validar el viaje: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }

    // Actualizar el estado
    setState(() {
      if (esIda) {
        _fechaHoraIda = combinedDateTime;
      } else {
        _fechaHoraVuelta = combinedDateTime;
      }
    });

    // Mostrar confirmación
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${esIda ? "Fecha y hora de ida" : "Fecha y hora de vuelta"} confirmadas: '
            '${combinedDateTime.day}/${combinedDateTime.month}/${combinedDateTime.year} '
            'a las ${combinedDateTime.hour.toString().padLeft(2, "0")}:${combinedDateTime.minute.toString().padLeft(2, "0")}'
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _continuarPaso3() {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => PublicarViajePaso3(
          ubicaciones: widget.ubicaciones,
          fechaHoraIda: _fechaHoraIda!,
          fechaHoraVuelta: _viajeIdaYVuelta ? _fechaHoraVuelta : null,
          viajeIdaYVuelta: _viajeIdaYVuelta,
        ),
      ),
    );
  }
}
