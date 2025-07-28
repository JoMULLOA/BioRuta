import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/contacto_emergencia.dart';
import '../services/emergencia_service.dart';
import '../widgets/navbar_para_sos.dart';
import 'tutorial_sos_screen.dart';
import 'configurar_contactos_screen.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  final EmergenciaService _emergenciaService = EmergenciaService();
  List<ContactoEmergencia> _contactos = [];
  bool _isLoading = true;
  bool _activandoEmergencia = false;
  Map<String, dynamic>? _infoViaje; // Información del viaje activo para SOS

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    
    // Obtener información del viaje desde los argumentos del navigator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      debugPrint('🔍 [SOS INIT] Argumentos recibidos: $args');
      if (args != null && args.containsKey('infoViaje')) {
        debugPrint('📋 [SOS INIT] Info viaje encontrada: ${args['infoViaje']}');
        setState(() {
          _infoViaje = args['infoViaje'];
        });
        debugPrint('✅ [SOS INIT] _infoViaje actualizada: $_infoViaje');
      } else {
        debugPrint('⚠️ [SOS INIT] No se encontró información del viaje en argumentos');
      }
    });
    
    // Inicializar timer para actualizar estado del tracking
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _actualizarEstadoTracking();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final contactos = await _emergenciaService.obtenerContactos();
      final tutorialCompletado = await _emergenciaService.tutorialCompletado();
      
      setState(() {
        _contactos = contactos;
        _isLoading = false;
      });

      // Si no hay contactos o no se ha completado el tutorial, mostrar tutorial
      if (!tutorialCompletado || contactos.isEmpty) {
        _mostrarTutorial();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  Future<void> _actualizarEstadoTracking() async {
    // Método mantenido para compatibilidad pero sin funcionalidad
    // ya que se eliminó el tracking de 8 horas
  }

  void _mostrarTutorial() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TutorialSOSScreen(),
      ),
    ).then((_) => _cargarDatos());
  }

  void _configurarContactos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConfigurarContactosScreen(),
      ),
    ).then((_) => _cargarDatos());
  }

  void _mostrarDialogoConfirmacion() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: const Color(0xFF854937), size: 28),
              const SizedBox(width: 8),
              const Text('⚠️ Activar Emergencia'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Estás seguro que quieres activar el modo de emergencia?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF854937).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF854937).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Se enviará un mensaje de emergencia a:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF854937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._contactos.map((contacto) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 16, color: const Color(0xFF854937)),
                          const SizedBox(width: 4),
                          Text(
                            '${contacto.nombre} (${contacto.telefono})',
                            style: TextStyle(color: const Color(0xFF6B3B2D)),
                          ),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _activarEmergencia();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF854937), // Usar color de la app
                foregroundColor: Colors.white,
              ),
              child: const Text('Sí, activar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _activarEmergencia() async {
    if (_activandoEmergencia) return;
    
    setState(() => _activandoEmergencia = true);
    
    try {
      // Simular nombre de usuario (en tu app real, obtenlo del estado global)
      const nombreUsuario = 'Usuario BioRuta';
      
      // Incluir información del viaje si está disponible
      Map<String, dynamic>? infoAdicional;
      debugPrint('🔍 [SOS] Verificando _infoViaje: $_infoViaje');
      if (_infoViaje != null) {
        infoAdicional = {
          'viaje': _infoViaje,
        };
        debugPrint('📋 [SOS] Enviando infoAdicional: $infoAdicional');
      } else {
        debugPrint('⚠️ [SOS] No hay información del viaje para enviar');
      }
      
      // Activar emergencia directamente con WhatsApp (sin timer de 8 horas)
      await _emergenciaService.activarEmergencia(
        nombreUsuario, 
        conTracking: false, // Solo enviar una vez, sin tracking
        infoAdicional: infoAdicional,
      );
      
      if (mounted) {
        // Mostrar confirmación de éxito
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text('Emergencia Activada'),
              ],
            ),
            content: const Text(
              '¡Alerta de emergencia enviada! '
              'Tus contactos han recibido tu ubicación por WhatsApp.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF854937), // Usar color de la app
                  foregroundColor: Colors.white,
                ),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error al activar emergencia: $e');
    } finally {
      setState(() => _activandoEmergencia = false);
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: const Text('SOS - Emergencia'),
        backgroundColor: const Color(0xFF854937), // Color café de la paleta
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _configurarContactos,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _mostrarTutorial,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      bottomNavigationBar: NavbarParaSOS(
        currentIndex: 3, // SOS estará en el índice 3 (en el medio)
        onTap: _onNavBarTap,
        onSOSLongPress: _mostrarDialogoConfirmacion, // Callback para long press en navbar
      ),
    );
  }

  void _onNavBarTap(int index) {
    // Mapeo directo de índices a rutas (sin SOS porque ya estamos aquí)
    final routes = [
      '/mis-viajes',  // 0
      '/mapa',        // 1  
      '/publicar',    // 2
      '/chat',        // 3
      '/ranking',     // 4
      '/perfil',      // 5
    ];
    
    if (index < routes.length) {
      Navigator.pushReplacementNamed(context, routes[index]);
    }
  }

  Widget _buildBody() {
    if (_contactos.isEmpty) {
      return _buildNoContactos();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStatusCard(),
          const SizedBox(height: 30),
          _buildContactosList(),
          const SizedBox(height: 20),
          _buildInstrucciones(),
        ],
      ),
    );
  }

  Widget _buildNoContactos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contact_emergency,
              size: 80,
              color: const Color(0xFF854937).withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            const Text(
              'No tienes contactos de emergencia',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF854937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Configura al menos 1 contacto de emergencia para usar el botón SOS',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B3B2D)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _configurarContactos,
                icon: const Icon(Icons.add),
                label: const Text('Configurar Contactos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF854937),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: Colors.green.shade600, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sistema SOS Activo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                Text(
                  '${_contactos.length} contacto${_contactos.length != 1 ? 's' : ''} configurado${_contactos.length != 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactosList() {
    return Container(
      width: double.infinity,
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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contacts, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text(
                'Contactos de Emergencia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF854937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._contactos.map((contacto) => _buildContactoItem(contacto)).toList(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _configurarContactos,
              icon: const Icon(Icons.edit),
              label: const Text('Editar Contactos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactoItem(ContactoEmergencia contacto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.red.shade100,
            child: Text(
              contacto.nombre.isNotEmpty ? contacto.nombre[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contacto.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _emergenciaService.formatearTelefono(contacto.telefono),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
        ],
      ),
    );
  }

  Widget _buildInstrucciones() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              Text(
                'Cómo usar el botón SOS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstruccionItem(
            '1.',
            'Mantén presionado el botón SOS por 2 segundos',
            Icons.touch_app,
          ),
          _buildInstruccionItem(
            '2.',
            'Confirma que quieres activar la emergencia',
            Icons.check_circle_outline,
          ),
          _buildInstruccionItem(
            '3.',
            'Se enviará tu ubicación por WhatsApp a tus contactos',
            Icons.location_on,
          ),
          const SizedBox(height: 8),
          Text(
            '⚠️ Úsalo solo en emergencias reales',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruccionItem(String numero, String texto, IconData icono) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.orange.shade600,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                numero,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icono, size: 16, color: Colors.orange.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: Colors.orange.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
