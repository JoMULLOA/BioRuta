import 'package:flutter/material.dart';
import '../widgets/navbar_con_sos_dinamico.dart';
import '../models/direccion_sugerida.dart';
import '../mapa/mapa_seleccion.dart';
import 'resultados_busqueda.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  int _selectedIndex = -1; // No hay selección por defecto, ya que no es pantalla principal
    // Variables para almacenar los datos del viaje
  String? direccionOrigen;
  String? direccionDestino;
  double? origenLat;
  double? origenLng;
  double? destinoLat;
  double? destinoLng;
  int pasajeros = 1;
  DateTime? fechaSeleccionada;
  
  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Obtener ubicación actual para el origen
    _obtenerUbicacionActual();
  }  Future<void> _obtenerUbicacionActual() async {
    try {
      // Por ahora usamos coordenadas fijas precisas de Concepción
      // En el futuro esto debería usar GPS real
      setState(() {
        direccionOrigen = "Mi ubicación actual (Concepción)";
        origenLat = -36.8270698; // Coordenadas más precisas de Concepción
        origenLng = -73.0502064;
        _origenController.text = "Mi ubicación actual (Concepción)";
      });
    } catch (e) {
      debugPrint("Error al obtener ubicación: $e");
      setState(() {
        direccionOrigen = "Seleccionar origen";
        _origenController.text = "Toca para seleccionar origen";
      });
    }
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2E7D32), // Verde
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != fechaSeleccionada) {
      setState(() {
        fechaSeleccionada = picked;
      });
    }
  }

  Future<void> _abrirMapaParaSeleccion(bool esOrigen) async {
    // Si es destino y ya tenemos origen, pasar esa información
    DireccionSugerida? origenSeleccionado;
    if (!esOrigen && direccionOrigen != null && origenLat != null && origenLng != null) {
      origenSeleccionado = DireccionSugerida(
        displayName: direccionOrigen!,
        lat: origenLat!,
        lon: origenLng!,
        esOrigen: true,
      );
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapaSeleccionPage(
          tituloSeleccion: esOrigen ? "Seleccionar Origen" : "Seleccionar Destino",
          esOrigen: esOrigen,
          origenSeleccionado: origenSeleccionado,
        ),
      ),
    );    if (result != null && result is DireccionSugerida) {
      setState(() {
        if (esOrigen) {
          direccionOrigen = result.displayName;
          origenLat = result.lat;
          origenLng = result.lon;
          _origenController.text = result.displayName;
        } else {
          direccionDestino = result.displayName;
          destinoLat = result.lat;
          destinoLng = result.lon;
          _destinoController.text = result.displayName;
        }
      });
    }
  }
  void _limpiarFormulario() {
    setState(() {
      direccionOrigen = null;
      direccionDestino = null;
      origenLat = null;
      origenLng = null;
      destinoLat = null;
      destinoLng = null;
      pasajeros = 1;
      fechaSeleccionada = null;
      _origenController.clear();
      _destinoController.clear();
    });
    _obtenerUbicacionActual();
  }
  void _buscarViaje() {
    if (direccionOrigen == null || direccionDestino == null || fechaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos'),
          backgroundColor: Color(0xFF070505),
        ),
      );
      return;
    }

    // Verificar que tenemos las coordenadas
    if (origenLat == null || origenLng == null || destinoLat == null || destinoLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona las ubicaciones desde el mapa'),
          backgroundColor: Color(0xFF070505),
        ),
      );
      return;
    }
    
    // Formatear fecha para el backend
    final String fechaFormateada = "${fechaSeleccionada!.year}-"
        "${fechaSeleccionada!.month.toString().padLeft(2, '0')}-"
        "${fechaSeleccionada!.day.toString().padLeft(2, '0')}";

    debugPrint('🔍 Navegando a resultados de búsqueda:');
    debugPrint('Origen: $direccionOrigen ($origenLat, $origenLng)');
    debugPrint('Destino: $direccionDestino ($destinoLat, $destinoLng)');
    debugPrint('Pasajeros: $pasajeros');
    debugPrint('Fecha: $fechaFormateada');

    // Navegar a la pantalla de resultados
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultadosBusquedaScreen(
          origenLat: origenLat!,
          origenLng: origenLng!,
          destinoLat: destinoLat!,
          destinoLng: destinoLng!,
          fechaViaje: fechaFormateada,
          pasajeros: pasajeros,
          origenTexto: direccionOrigen!,
          destinoTexto: direccionDestino!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // Logo de BioRuta
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF070505).withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icon/bioruta.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.directions_car,
                        size: 60,
                        color: Color(0xFF854937),
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Título
              const Text(
                'BioRuta',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF854937),
                ),
              ),
              
              Text(
                'Encuentra tu viaje ideal',
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF070505).withOpacity(0.6),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Tarjeta principal
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF070505).withOpacity(0.08),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Campo "De" (Origen)
                    GestureDetector(
                      onTap: () => _abrirMapaParaSeleccion(true),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFEDCAB6)),
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFEDCAB6).withOpacity(0.1),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.my_location,
                              color: Color(0xFF854937),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'De',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF854937),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    direccionOrigen ?? 'Seleccionar origen',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF070505),
                                    ),
                                    maxLines: 1,
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
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Campo "A" (Destino)
                    GestureDetector(
                      onTap: () => _abrirMapaParaSeleccion(false),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFEDCAB6)),
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFEDCAB6).withOpacity(0.1),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place,
                              color: Color(0xFF854937),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'A',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF854937),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    direccionDestino ?? 'Seleccionar destino',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF070505),
                                    ),
                                    maxLines: 1,
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
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Selector de rango
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFEDCAB6)),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFEDCAB6).withOpacity(0.1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pasajeros',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF854937),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(4, (index) {
                              final value = index + 1;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    pasajeros = value;
                                  });
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: pasajeros == value
                                        ? const Color(0xFF854937)
                                        : Colors.white,
                                    border: Border.all(
                                      color: const Color(0xFF854937),
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      value.toString(),
                                      style: TextStyle(
                                        color: pasajeros == value
                                            ? Colors.white
                                            : const Color(0xFF854937),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Selector de fecha
                    GestureDetector(
                      onTap: _seleccionarFecha,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFEDCAB6)),
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFEDCAB6).withOpacity(0.1),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Color(0xFF854937),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fecha del viaje',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF854937),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    fechaSeleccionada != null
                                        ? '${fechaSeleccionada!.day}/${fechaSeleccionada!.month}/${fechaSeleccionada!.year}'
                                        : 'Seleccionar fecha',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF070505),
                                    ),
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
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Botón de búsqueda
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _buscarViaje,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF854937),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          'Buscar Viaje',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Botón de limpiar
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: TextButton(
                        onPressed: _limpiarFormulario,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF854937),
                        ),
                        child: const Text(
                          'Limpiar formulario',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavbarConSOSDinamico(
        currentIndex: _selectedIndex,
        onTap: (index) {
          // Evitar navegación innecesaria si ya estamos en la pantalla actual
          if (index == _selectedIndex) return;
          
          setState(() {
            _selectedIndex = index;
          });
          
          // Navegación según el índice seleccionado
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/mis-viajes');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/mapa');
              break;
            case 2:
              // Publicar viaje
              Navigator.pushReplacementNamed(context, '/publicar');
              break;
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
      ),    );
  }


  @override
  void dispose() {
    _origenController.dispose();
    _destinoController.dispose();
    super.dispose();  }
}
