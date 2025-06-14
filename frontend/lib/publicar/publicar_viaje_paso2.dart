import "package:flutter/material.dart";
import "../models/direccion_sugerida.dart";
import "publicar_viaje_paso3.dart";

class PublicarViajePaso2 extends StatefulWidget {
  final List<DireccionSugerida> ubicaciones;

  const PublicarViajePaso2({
    super.key,
    required this.ubicaciones,
  });

  @override
  State<PublicarViajePaso2> createState() => _PublicarViajePaso2State();
}

class _PublicarViajePaso2State extends State<PublicarViajePaso2> {
  DateTime? _fechaIda;
  TimeOfDay? _horaIda;
  DateTime? _fechaVuelta;
  TimeOfDay? _horaVuelta;
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
                                  _fechaVuelta = null;
                                  _horaVuelta = null;
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
              _buildDateTimeCard(title: "Viaje de ida", icon: Icons.flight_takeoff, fecha: _fechaIda, hora: _horaIda, onSelectDate: () => _seleccionarFecha(true), onSelectTime: () => _seleccionarHora(true)),
              const SizedBox(height: 20),
              if (_viajeIdaYVuelta) _buildDateTimeCard(title: "Viaje de vuelta", icon: Icons.flight_land, fecha: _fechaVuelta, hora: _horaVuelta, onSelectDate: () => _seleccionarFecha(false), onSelectTime: () => _seleccionarHora(false)),
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

  Widget _buildDateTimeCard({required String title, required IconData icon, required DateTime? fecha, required TimeOfDay? hora, required VoidCallback onSelectDate, required VoidCallback onSelectTime}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: const Color(0xFF854937).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Icon(icon, color: const Color(0xFF854937)),
              ),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF854937))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onSelectDate,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF854937)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(fecha != null ? "${fecha.day}/${fecha.month}/${fecha.year}" : "Seleccionar fecha", style: TextStyle(color: fecha != null ? Colors.black : Colors.grey), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onSelectTime,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF854937)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(hora != null ? "${hora.hour.toString().padLeft(2, "0")}:${hora.minute.toString().padLeft(2, "0")}" : "Seleccionar hora", style: TextStyle(color: hora != null ? Colors.black : Colors.grey), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _puedeAvanzar {
    if (_fechaIda == null || _horaIda == null) return false;
    if (_viajeIdaYVuelta && (_fechaVuelta == null || _horaVuelta == null)) return false;
    return true;
  }

  Future<void> _seleccionarFecha(bool esIda) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF854937))), child: child!);
      },
    );
    if (picked != null) {
      setState(() {
        if (esIda) {
          _fechaIda = picked;
        } else {
          _fechaVuelta = picked;
        }
      });
    }
  }

  Future<void> _seleccionarHora(bool esIda) async {
    final TimeOfDay initialTime = (!esIda && _viajeIdaYVuelta) ? const TimeOfDay(hour: 14, minute: 0) : const TimeOfDay(hour: 14, minute: 0);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF854937))), child: child!);
      },
    );
    if (picked != null) {
      setState(() {
        if (esIda) {
          _horaIda = picked;
        } else {
          _horaVuelta = picked;
        }
      });
    }
  }

  void _continuarPaso3() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PublicarViajePaso3(ubicaciones: widget.ubicaciones, fechaIda: _fechaIda!, horaIda: _horaIda!, fechaVuelta: _fechaVuelta, horaVuelta: _horaVuelta, viajeIdaYVuelta: _viajeIdaYVuelta)));
  }
}
