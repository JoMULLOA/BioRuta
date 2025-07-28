import 'package:flutter/material.dart';
import '../services/emergencia_service.dart';
import 'configurar_contactos_screen.dart';

class TutorialSOSScreen extends StatefulWidget {
  const TutorialSOSScreen({super.key});

  @override
  State<TutorialSOSScreen> createState() => _TutorialSOSScreenState();
}

class _TutorialSOSScreenState extends State<TutorialSOSScreen> {
  final PageController _pageController = PageController();
  final EmergenciaService _emergenciaService = EmergenciaService();
  int _currentPage = 0;
  bool _isLoading = false;

  final List<TutorialPage> _pages = [
    TutorialPage(
      title: '¡Bienvenido al Sistema SOS!',
      description: 'El botón SOS está diseñado para situaciones de emergencia real durante tus viajes.',
      icon: Icons.shield_outlined,
      color: const Color(0xFF854937), // Color principal de la app
      details: [
        'Envía tu ubicación automáticamente',
        'Alerta a tus contactos de confianza',
        'Funciona incluso con poca señal',
        'Activación rápida en 2 segundos',
      ],
    ),
    TutorialPage(
      title: 'Configura tus Contactos',
      description: 'Necesitas entre 1 y 3 contactos de emergencia que puedan ayudarte en caso necesario.',
      icon: Icons.contacts,
      color: const Color(0xFF6B3B2D), // Color secundario de la app
      details: [
        'Mínimo 1 contacto, máximo 3',
        'Deben tener WhatsApp activo',
        'Preferiblemente familiares o amigos cercanos',
        'Con números de teléfono válidos',
      ],
    ),
    TutorialPage(
      title: 'Cómo Activar la Emergencia',
      description: 'El botón SOS requiere una acción deliberada para evitar activaciones accidentales.',
      icon: Icons.touch_app,
      color: const Color(0xFF854937), // Color principal
      details: [
        'Mantén presionado el botón por 2 segundos',
        'Aparecerá un diálogo de confirmación',
        'Confirma que quieres activar la emergencia',
        'Se enviará automáticamente la alerta',
      ],
    ),
    TutorialPage(
      title: 'Mensaje de Emergencia',
      description: 'Tus contactos recibirán un mensaje detallado con tu información y ubicación.',
      icon: Icons.message,
      color: const Color(0xFF6B3B2D), // Color secundario
      details: [
        'Incluye tu nombre y la app (BioRuta)',
        'Nombre, conductor y patente del vehículo',
        'Muestra tu ubicación actual en Google Maps',
        'Se envía por WhatsApp automáticamente',
        'Mensaje claro indicando que es una emergencia',
      ],
    ),
    TutorialPage(
      title: '⚠️ Uso Responsable',
      description: 'El sistema SOS debe usarse ÚNICAMENTE en emergencias reales.',
      icon: Icons.warning_amber_rounded,
      color: const Color(0xFF854937), // Color principal de la app
      details: [
        'Solo para situaciones de peligro real',
        'No usar como broma o prueba',
        'Puede causar alarma innecesaria',
        'Úsalo con responsabilidad y criterio',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completarTutorial() async {
    setState(() => _isLoading = true);
    
    try {
      await _emergenciaService.marcarTutorialCompletado();
      
      if (mounted) {
        // Ir a configurar contactos pasando información que viene del tutorial
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ConfigurarContactosScreen(),
            settings: const RouteSettings(
              arguments: {'fromTutorial': true},
            ),
          ),
        );
        
        // Al regresar de configurar contactos, resetear el loading
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al completar tutorial: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _saltarTutorial() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Saltar Tutorial?'),
        content: const Text(
          'Es importante que entiendas cómo funciona el sistema SOS antes de usarlo. '
          '¿Estás seguro que quieres saltar el tutorial?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuar Tutorial'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completarTutorial();
            },
            child: const Text('Sí, saltar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: const Text('Tutorial SOS'),
        backgroundColor: const Color(0xFF854937), // Color café de la app
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentPage > 0) {
              // Si no estamos en la primera página, retroceder página
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              // Si estamos en la primera página, salir del tutorial
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: _saltarTutorial,
            child: const Text(
              'Saltar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Indicador de progreso
          Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / _pages.length,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(_pages[_currentPage].color),
            ),
          ),
          
          // Contenido del tutorial
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                return _buildTutorialPage(_pages[index]);
              },
            ),
          ),
          
          // Botones de navegación
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildTutorialPage(TutorialPage page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Icono principal
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: page.color,
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Título
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: page.color,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Descripción
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6B3B2D),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 30),
          
          // Detalles
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 0,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Características:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: page.color,
                  ),
                ),
                const SizedBox(height: 16),
                ...page.details.map((detail) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6, right: 12),
                        decoration: BoxDecoration(
                          color: page.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          detail,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF333333),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Indicadores de página
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index == _currentPage 
                      ? _pages[_currentPage].color 
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
          
          const SizedBox(height: 20),
          
          // Botones de navegación
          Row(
            children: [
              // Botón anterior
              if (_currentPage > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _pages[_currentPage].color,
                      side: BorderSide(color: _pages[_currentPage].color),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Anterior'),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              
              const SizedBox(width: 16),
              
              // Botón siguiente/finalizar
              Expanded(
                flex: 2, // Hacer el botón principal más grande
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _completarTutorial();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _currentPage < _pages.length - 1 ? 'Siguiente' : 'Configurar Contactos',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TutorialPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> details;

  TutorialPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.details,
  });
}
