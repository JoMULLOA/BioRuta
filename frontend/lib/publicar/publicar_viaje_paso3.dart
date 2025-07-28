import 'package:flutter/material.dart';
import '../models/direccion_sugerida.dart';
import '../services/user_service.dart'; // Importar UserService para verificar género
import 'publicar_viaje_final.dart';

class PublicarViajePaso3 extends StatefulWidget {
  final List<DireccionSugerida> ubicaciones;
  final DateTime fechaHoraIda;
  final DateTime? fechaHoraVuelta;
  final bool viajeIdaYVuelta;

  const PublicarViajePaso3({
    super.key,
    required this.ubicaciones,
    required this.fechaHoraIda,
    this.fechaHoraVuelta,
    required this.viajeIdaYVuelta,
  });

  @override
  State<PublicarViajePaso3> createState() => _PublicarViajePaso3State();
}

class _PublicarViajePaso3State extends State<PublicarViajePaso3> {
  bool _soloMujeres = false;
  String _flexibilidadSalida = 'Puntual';
  bool _esUsuarioFemenino = false; // Variable para determinar si el usuario es mujer
  bool _cargandoGenero = true; // Variable para controlar estado de carga
  
  // Flag para debug - cambiar a false en producción
  static const bool _debugMode = false;

  final List<String> _opcionesFlexibilidad = [
    'Puntual',
    '± 5 minutos',
    '± 10 minutos',
    '± 15 minutos',
  ];

  @override
  void initState() {
    super.initState();
    _verificarGeneroUsuario(); // Verificar género al inicializar
  }

  /// Verificar el género del usuario para mostrar opciones específicas
  Future<void> _verificarGeneroUsuario() async {
    try {
      final perfilUsuario = await UserService.obtenerPerfilUsuario();
      
      if (perfilUsuario != null && mounted) {
        final genero = perfilUsuario['genero']?.toString().toLowerCase().trim();
        
        // Verificar si es femenino según los valores del backend
        final esFemenino = genero == 'femenino';
        
        setState(() {
          _esUsuarioFemenino = esFemenino;
          _cargandoGenero = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _esUsuarioFemenino = false;
            _cargandoGenero = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _esUsuarioFemenino = false;
          _cargandoGenero = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: const Text('Paso 3: Configuración'),
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
            _buildProgressIndicator(3),
            
            const SizedBox(height: 30),
            
            const Text(
              'Configura tu viaje',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF854937),
              ),
            ),
            
            const SizedBox(height: 10),
            
            const Text(
              'Define los detalles y preferencias para tu viaje',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B3B2D),
              ),
            ),
              const SizedBox(height: 30),
            
            // DEBUG: Mostrar estado actual
            if (_debugMode) // Activar/desactivar con el flag
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEBUG INFO:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Cargando género: $_cargandoGenero',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      'Es usuario femenino: $_esUsuarioFemenino',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      'Solo mujeres activado: $_soloMujeres',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _cargandoGenero = true;
                            });
                            _verificarGeneroUsuario();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF854937),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(100, 32),
                          ),
                          child: const Text('Reverificar', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _esUsuarioFemenino = !_esUsuarioFemenino;
                              _cargandoGenero = false;
                            });
                            print('🔄 Género forzado a: ${_esUsuarioFemenino ? "femenino" : "masculino"}');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(100, 32),
                          ),
                          child: const Text('Alternar', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            
            // Preferencias de género (solo para usuarios femeninos)
            if (_cargandoGenero)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xFF854937)),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Verificando perfil de usuario...',
                          style: TextStyle(
                            color: Color(0xFF854937),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_esUsuarioFemenino)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: _buildConfigCard(
                  title: 'Preferencias de pasajeros',
                  icon: Icons.person_outline,
                  child: SwitchListTile(
                    title: const Text('Solo mujeres'),
                    subtitle: const Text('Viaje exclusivo para mujeres'),
                    value: _soloMujeres,
                    activeColor: const Color(0xFF854937),
                    onChanged: (value) {
                      setState(() {
                        _soloMujeres = value;
                      });
                    },
                  ),
                ),
              ),
            
            // Flexibilidad de horario
            _buildConfigCard(
              title: 'Flexibilidad de horario',
              icon: Icons.schedule,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Flexibilidad en la hora de salida:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ..._opcionesFlexibilidad.map((opcion) => RadioListTile<String>(
                    title: Text(opcion),
                    value: opcion,
                    groupValue: _flexibilidadSalida,
                    activeColor: const Color(0xFF854937),
                    onChanged: (value) {
                      setState(() {
                        _flexibilidadSalida = value!;
                      });
                    },
                  )),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Botón siguiente
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _continuarFinal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF854937),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Finalizar Configuración',
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

  Widget _buildConfigCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          spreadRadius: 1,
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
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
          color: const Color(0xFF854937).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
                child: Icon(
                  icon,
                  color: const Color(0xFF854937),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF854937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
  void _continuarFinal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicarViajeFinal(
          ubicaciones: widget.ubicaciones,
          fechaHoraIda: widget.fechaHoraIda,
          fechaHoraVuelta: widget.fechaHoraVuelta,
          viajeIdaYVuelta: widget.viajeIdaYVuelta,
          soloMujeres: _soloMujeres,
          flexibilidadSalida: _flexibilidadSalida,
        ),
      ),
    );
  }
}