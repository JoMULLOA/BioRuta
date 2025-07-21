import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/navbar_con_sos_dinamico.dart';
import '../widgets/radar_animation_widget.dart';
import '../models/direccion_sugerida.dart';
import '../models/marcador_viaje_model.dart';
import '../services/ubicacion_service.dart';
import '../services/busqueda_service.dart';
import '../services/viaje_service.dart';
import '../services/ruta_service.dart';
import '../services/user_service.dart'; // Importar UserService
import 'mapa_widget.dart';
import 'mapa_seleccion.dart';
import 'mapa_ui_components.dart';
import '../buscar/resultados_busqueda.dart';


class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late MapController controller;
  final TextEditingController destinoController = TextEditingController();
  int _selectedIndex = 1; // Mapa está en índice 1 cuando showSOS = true
  Timer? _debounceTimer;
  String _regionActual = "Desconocida";
  
  // Variables para los marcadores de viajes
  List<MarcadorViaje> _marcadoresViajes = [];
  bool _cargandoViajes = false;
  Map<String, GeoPoint> _marcadoresEnMapa = {};

  // Variables para manejar rutas específicas pasadas como argumentos
  bool _rutaEspecificaCargada = false;

  // ===== NUEVAS VARIABLES PARA FUNCIONALIDAD DE BÚSQUEDA =====
  // Variables para almacenar los datos del viaje
  String? direccionOrigen;
  String? direccionDestino;
  double? origenLat;
  double? origenLng;
  double? destinoLat;
  double? destinoLng;
  int pasajeros = 1;
  DateTime? fechaSeleccionada;
  bool soloMujeres = false; // Nueva variable para la opción "Solo mujeres"
  bool esUsuarioMujer = false; // Variable para determinar si el usuario es mujer
  
  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();

  // Estado de la búsqueda
  bool _mostrandoFormularioBusqueda = false;

  // Variables para funcionalidad de radar
  bool _radarActivo = false;
  bool _mostrandoAnimacionRadar = false;
  GeoPoint? _marcadorRadar;
  List<Map<String, dynamic>> _viajesEnRadio = [];
  final double _radioKm = 0.5; // Radio de 500 metros para búsqueda más precisa
  List<String> _marcadoresViajesIds = []; // Para trackear marcadores añadidos
  Map<String, String> _marcadorViajeMap = {}; // Mapea ID de marcador con ID de viaje

  @override
  void initState() {
    super.initState();
    controller = MapController.withUserPosition(
      trackUserLocation: const UserTrackingOption(
        enableTracking: true,
        unFollowUser: false,
      ),
    );
    
    // Inicializar valores por defecto para la barra superior
    _inicializarValoresPorDefecto();
    
    // Verificar género del usuario
    _verificarGeneroUsuario();
    
    // Registrar callback para recibir notificaciones de cambios de ruta
    RutaService.instance.registrarMapaCallback(_onRutaChanged);
    
    _inicializarUbicacion();
    _cargarMarcadoresViajes();
    
    // Verificar si hay una ruta activa después de que el widget esté construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarRutaActiva();
    });
  }

  // ===== MÉTODOS PARA FUNCIONALIDAD DE BÚSQUEDA =====

  /// Inicializar valores por defecto para la barra superior
  void _inicializarValoresPorDefecto() {
    // Establecer fecha de hoy por defecto
    fechaSeleccionada = DateTime.now();
    // pasajeros ya está inicializado en 1 por defecto
    // direccionOrigen se establecerá cuando se obtenga la región actual
  }

  /// Verificar si el usuario actual es mujer
  Future<bool> _esUsuarioMujer() async {
    try {
      final perfilUsuario = await UserService.obtenerPerfilUsuario();
      if (perfilUsuario != null && perfilUsuario['genero'] != null) {
        return perfilUsuario['genero'].toString().toLowerCase() == 'femenino';
      }
      return false; // Por defecto false si no se puede obtener el género
    } catch (e) {
      print('Error al verificar género del usuario: $e');
      return false; // Por defecto false en caso de error
    }
  }

  /// Verificar el género del usuario para mostrar opciones específicas
  void _verificarGeneroUsuario() async {
    try {
      final esMujer = await _esUsuarioMujer();
      if (mounted) {
        setState(() {
          esUsuarioMujer = esMujer;
        });
      }
    } catch (e) {
      print('Error al verificar género del usuario: $e');
    }
  }

  /// Abrir modal de búsqueda rápida al tocar la barra superior
  void _abrirBusquedaAvanzada() {
    if (!mounted) return; // Verificar que el widget esté montado
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Título
              const Text(
                '¿A dónde vas?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF854937),
                ),
              ),
              const SizedBox(height: 20),
              
              // Origen (ahora editable)
              GestureDetector(
                onTap: () async {
                  Navigator.pop(context); // Cerrar modal
                  await _seleccionarOrigen();
                  if (mounted) _abrirBusquedaAvanzada(); // Reabrir modal con nuevo origen
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF854937)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, color: Color(0xFF854937)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          direccionOrigen ?? 'Mi ubicación actual',
                          style: TextStyle(
                            fontSize: 16,
                            color: direccionOrigen != null ? Colors.black87 : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Destino
              GestureDetector(
                onTap: () async {
                  Navigator.pop(context); // Cerrar modal
                  await _seleccionarDestino();
                  if (mounted) _abrirBusquedaAvanzada(); // Reabrir modal con nuevo destino
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF854937)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF854937)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          direccionDestino ?? 'Seleccionar destino',
                          style: TextStyle(
                            fontSize: 16,
                            color: direccionDestino != null ? Colors.black87 : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Fecha y pasajeros en una fila
              Row(
                children: [
                  // Fecha
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await _seleccionarFecha();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF854937)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Color(0xFF854937), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                fechaSeleccionada != null
                                    ? "${fechaSeleccionada!.day}/${fechaSeleccionada!.month}"
                                    : 'Fecha',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Pasajeros
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF854937)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (pasajeros > 1 && mounted) {
                              setState(() {
                                pasajeros--;
                              });
                              setModalState(() {}); // Actualizar modal inmediatamente
                            }
                          },
                          icon: const Icon(Icons.remove, color: Color(0xFF854937)),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        Text('$pasajeros', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: () {
                            if (pasajeros < 5 && mounted) {
                              setState(() {
                                pasajeros++;
                              });
                              setModalState(() {}); // Actualizar modal inmediatamente
                            }
                          },
                          icon: const Icon(Icons.add, color: Color(0xFF854937)),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Opción "Solo mujeres" - Solo visible para usuarias mujeres
              if (esUsuarioMujer) ...[
                Row(
                  children: [
                    Checkbox(
                      value: soloMujeres,
                      onChanged: (value) {
                        setState(() {
                          soloMujeres = value ?? false;
                        });
                        setModalState(() {}); // Actualizar modal inmediatamente
                      },
                      activeColor: const Color(0xFF854937),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Solo mujeres',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              
              // Botón de búsqueda (sin "Más opciones")
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (mounted) _buscarViajes();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF854937),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Buscar viajes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ), // Fin del Column
        ), // Fin del Padding
      ), // Fin del Container
      ), // Fin del StatefulBuilder
    ); // Fin del showModalBottomSheet
  }
  
  void _toggleFormularioBusqueda() {
    setState(() {
      _mostrandoFormularioBusqueda = !_mostrandoFormularioBusqueda;
    });
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != fechaSeleccionada && mounted) { // Verificar mounted
      setState(() {
        fechaSeleccionada = picked;
      });
    }
  }

  void _incrementarPasajeros() {
    if (pasajeros < 5 && mounted) { // Máximo 5 pasajeros
      setState(() {
        pasajeros++;
      });
    }
  }

  void _decrementarPasajeros() {
    if (pasajeros > 1 && mounted) { // Verificar mounted
      setState(() {
        pasajeros--;
      });
    }
  }

  Future<void> _buscarViajes() async {
    if (direccionOrigen == null || direccionDestino == null || fechaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    // Verificar que tengamos las coordenadas necesarias
    if (origenLat == null || origenLng == null || destinoLat == null || destinoLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se pudieron obtener las coordenadas. Intenta seleccionar las ubicaciones nuevamente.')),
      );
      return;
    }

    // Formatear la fecha como string
    final fechaFormateada = "${fechaSeleccionada!.year}-${fechaSeleccionada!.month.toString().padLeft(2, '0')}-${fechaSeleccionada!.day.toString().padLeft(2, '0')}";

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
          soloMujeres: soloMujeres, // Parámetro implementado
        ),
      ),
    );
  }

  Future<void> _seleccionarOrigen() async {
    final direccion = await Navigator.push<DireccionSugerida>(
      context,
      MaterialPageRoute(
        builder: (context) => const MapaSeleccionPage(
          tituloSeleccion: 'Seleccionar origen',
          esOrigen: true,
        ),
      ),
    );

    if (direccion != null && mounted) { // Verificar si el widget está montado
      setState(() {
        direccionOrigen = direccion.displayName;
        origenLat = direccion.lat;
        origenLng = direccion.lon;
        _origenController.text = direccion.displayName;
      });
    }
  }

  Future<void> _seleccionarDestino() async {
    final direccion = await Navigator.push<DireccionSugerida>(
      context,
      MaterialPageRoute(
        builder: (context) => const MapaSeleccionPage(
          tituloSeleccion: 'Seleccionar destino',
          esOrigen: false,
        ),
      ),
    );

    if (direccion != null && mounted) { // Verificar si el widget está montado
      setState(() {
        direccionDestino = direccion.displayName;
        destinoLat = direccion.lat;
        destinoLng = direccion.lon;
        _destinoController.text = direccion.displayName;
      });
    }
  }

  @override
  void dispose() {
    // Cancelar cualquier operación asíncrona pendiente
    _debounceTimer?.cancel();
    
    // Limpiar el callback del servicio de ruta
    RutaService.instance.limpiarCallback();
    
    // Limpiar controladores
    destinoController.dispose();
    _origenController.dispose();
    _destinoController.dispose();
    
    // Llamar al dispose del padre
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Verificar si hay argumentos de ruta específica (para compatibilidad con navegación directa)
    if (!_rutaEspecificaCargada) {
      final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      
      if (arguments != null) {
        if (arguments.containsKey('origen') && arguments.containsKey('destino')) {
          _rutaEspecificaCargada = true;
          _mostrarRutaEspecifica(arguments);
        }
      }
    }
  }

  Future<void> _inicializarUbicacion() async {
    final serviciosActivos = await UbicacionService.verificarServiciosUbicacion();
    if (!serviciosActivos) {
      if (mounted) {
        UbicacionService.mostrarDialogoPermiso(context, 
          "Por favor activa los servicios de ubicación desde los ajustes del sistema.");
      }
      return;
    }
    await _solicitarPermisos();
  }

  Future<void> _solicitarPermisos() async {
    final status = await UbicacionService.solicitarPermisos();
    if (status.isGranted) {
      debugPrint("✅ Permiso de ubicación concedido");
      // Esperar un poco para que el controlador del mapa esté listo
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _centrarEnMiUbicacionConRegion();
      }
    } else if (status.isDenied) {
      if (mounted) {
        UbicacionService.mostrarDialogoPermiso(context,
          "Permiso de ubicación denegado. El mapa podría no funcionar correctamente.");
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        UbicacionService.mostrarDialogoPermiso(context,
          "Debes activar el permiso de ubicación manualmente en los ajustes.");
      }
      await openAppSettings();
    }
  }

  Future<void> _centrarEnMiUbicacionConRegion() async {
    try {
      GeoPoint? miPosicion = await controller.myLocation();

      String region = await BusquedaService.identificarRegion(miPosicion);
      
      if (mounted) { // Verificar antes de setState
        setState(() {
          _regionActual = region;
          // Establecer "Mi ubicación actual" como origen por defecto si no se ha seleccionado uno
          if (direccionOrigen == null) {
            direccionOrigen = 'Mi ubicación actual';
            origenLat = miPosicion.latitude;
            origenLng = miPosicion.longitude;
            _origenController.text = 'Mi ubicación actual';
          }
        });
      }

      await controller.moveTo(miPosicion);
      // Zoom level 15 para mostrar aproximadamente 1km de radio
      await controller.setZoom(zoomLevel: 15.0);
      
      debugPrint("📍 Ubicado en: $region (${miPosicion.latitude}, ${miPosicion.longitude})");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Ubicado en: $region'),
            backgroundColor: const Color(0xFF854937),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error al centrar en ubicación: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al obtener la ubicación'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cargarMarcadoresViajes() async {
    try {
      if (!mounted) return; // Verificar si el widget está montado
      
      setState(() {
        _cargandoViajes = true;
      });

      final marcadoresObtenidos = await ViajeService.obtenerMarcadoresViajes();
      
      if (!mounted) return; // Verificar nuevamente después de la operación async
      
      setState(() {
        _marcadoresViajes = marcadoresObtenidos;
        _cargandoViajes = false;
      });

      await _agregarMarcadoresAlMapa();
    } catch (e) {
      debugPrint('❌ Error al cargar marcadores de viajes: $e');
      if (mounted) { // Solo llamar setState si el widget está montado
        setState(() {
          _cargandoViajes = false;
        });
      }
    }
  }

  Future<void> _agregarMarcadoresAlMapa() async {
    try {
      if (!mounted) return; // Verificar si el widget está montado
      
      // Limpiar marcadores existentes
      for (final punto in _marcadoresEnMapa.values) {
        await controller.removeMarker(punto);
      }
      _marcadoresEnMapa.clear();

      // Agregar nuevos marcadores
      for (final marcador in _marcadoresViajes) {
        if (!mounted) return; // Verificar en cada iteración
        
        final geoPoint = GeoPoint(
          latitude: marcador.origen.latitud,
          longitude: marcador.origen.longitud,
        );

        await controller.addMarker(
          geoPoint,
          markerIcon: const MarkerIcon(
            icon: Icon(
              Icons.directions_car,
              color: Color(0xFF854937),
              size: 48,
            ),
          ),
        );

        _marcadoresEnMapa[marcador.id] = geoPoint;
      }
    } catch (e) {
      debugPrint('❌ Error al agregar marcadores al mapa: $e');
    }
  }

  Future<void> _mostrarDetallesViaje(String marcadorId) async {
    final marcador = _marcadoresViajes.firstWhere(
      (m) => m.id == marcadorId,
      orElse: () => throw Exception('Marcador no encontrado'),
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF2EEED),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de arrastre
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Título del viaje
              Text(
                'Viaje Disponible',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF854937),
                ),
              ),
              const SizedBox(height: 16),
              
              // Información del conductor
              if (marcador.detallesViaje.conductor != null)
                _buildInfoRow(Icons.person, 'Conductor', marcador.detallesViaje.conductor!.nombre),
              
              // Origen y destino
              _buildInfoRow(Icons.location_on, 'Origen', marcador.origen.nombre),
              _buildInfoRow(Icons.flag, 'Destino', marcador.destino.nombre),
              
              // Fecha y hora
              _buildInfoRow(Icons.calendar_today, 'Fecha', 
                '${marcador.detallesViaje.fecha.day}/${marcador.detallesViaje.fecha.month}/${marcador.detallesViaje.fecha.year}'),
              _buildInfoRow(Icons.access_time, 'Hora', marcador.detallesViaje.hora),
              
              // Plazas disponibles
              _buildInfoRow(Icons.airline_seat_recline_normal, 'Plazas disponibles', 
                '${marcador.detallesViaje.plazasDisponibles}'),
              
              // Precio
              _buildInfoRow(Icons.attach_money, 'Precio', '\$${marcador.detallesViaje.precio.toStringAsFixed(0)}'),
              
              // Vehículo
              if (marcador.detallesViaje.vehiculo != null)
                _buildInfoRow(Icons.directions_car, 'Vehículo', 
                  '${marcador.detallesViaje.vehiculo!.modelo} (${marcador.detallesViaje.vehiculo!.color})'),
              
              const SizedBox(height: 20),
              
              // Botón para unirse al viaje
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _unirseAlViaje(marcador),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF854937),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Unirse al Viaje',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF854937)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF854937),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(color: Color(0xFF070505)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unirseAlViaje(MarcadorViaje marcador) async {
    try {
      // Cerrar el modal
      Navigator.pop(context);
      
      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enviando solicitud...'),
            backgroundColor: Color(0xFF854937),
          ),
        );
      }

      final resultado = await ViajeService.unirseAViaje(marcador.id);

      if (mounted) {
        // Mensaje específico para el nuevo flujo de notificaciones
        String mensaje = resultado['message'] ?? 'Solicitud enviada';
        if (resultado['success'] == true) {
          mensaje = 'Solicitud enviada al conductor. Espera su respuesta en tus notificaciones.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: resultado['success'] == true 
                ? const Color(0xFF854937) 
                : Colors.red,
            duration: const Duration(seconds: 4), // Más tiempo para leer el mensaje
          ),
        );
      }

      // No recargar marcadores inmediatamente ya que el pasajero no se une directamente
      // Los marcadores se actualizarán cuando el conductor acepte/rechace la solicitud
    } catch (e) {
      debugPrint('❌ Error al unirse al viaje: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar la solicitud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onMapTap(GeoPoint geoPoint) {
    // Buscar si el tap está cerca de algún marcador de viaje
    for (final entry in _marcadoresEnMapa.entries) {
      final marcadorId = entry.key;
      final marcadorPunto = entry.value;
      
      // Calcular distancia entre el tap y el marcador
      final distancia = _calcularDistancia(
        geoPoint.latitude, geoPoint.longitude,
        marcadorPunto.latitude, marcadorPunto.longitude,
      );
      
      // Si el tap está cerca del marcador (dentro de 100 metros)
      if (distancia < 100) {
        _mostrarDetallesViaje(marcadorId);
        return;
      }
    }
  }

  double _calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    const double c = 6371000; // Radio de la Tierra en metros
    
    final double a = 0.5 - math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) *
        (1 - math.cos((lon2 - lon1) * p)) / 2;
    
    return c * 2 * math.asin(math.sqrt(a));
  }

  Future<void> _mostrarRutaEspecifica(Map<String, dynamic> arguments) async {
    try {
      debugPrint("🗺️ Mostrando ruta específica con argumentos: $arguments");
      
      final origenData = arguments['origen'] as Map<String, dynamic>;
      final destinoData = arguments['destino'] as Map<String, dynamic>;
      
      final origen = GeoPoint(
        latitude: origenData['lat'] as double,
        longitude: origenData['lng'] as double,
      );
      
      final destino = GeoPoint(
        latitude: destinoData['lat'] as double,
        longitude: destinoData['lng'] as double,
      );

      // Esperar a que el mapa esté listo
      await Future.delayed(const Duration(milliseconds: 500));

      // Remover rutas anteriores
      await controller.removeLastRoad();

      // Dibujar la ruta
      await controller.drawRoad(
        origen,
        destino,
        roadType: RoadType.car,
        roadOption: const RoadOption(roadColor: Color(0xFF854937)),
      );

      // Agregar marcadores
      await controller.addMarker(
        origen,
        markerIcon: const MarkerIcon(
          icon: Icon(Icons.location_on, color: Color(0xFF1B5E20), size: 56),
        ),
      );

      await controller.addMarker(
        destino,
        markerIcon: const MarkerIcon(
          icon: Icon(Icons.flag, color: Color(0xFFEDCAB6), size: 56),
        ),
      );

      // Centrar el mapa para mostrar ambos puntos
      await _centrarMapaEnRuta(origen, destino);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚗 Ruta del viaje mostrada'),
            backgroundColor: Color(0xFF854937),
          ),
        );
      }

    } catch (e) {
      debugPrint("❌ Error al mostrar ruta específica: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error al mostrar la ruta del viaje'),
            backgroundColor: Color(0xFF070505),
          ),
        );
      }
    }
  }

  Future<void> _centrarMapaEnRuta(GeoPoint origen, GeoPoint destino) async {
    try {
      // Calcular el punto central y el zoom apropiado
      final latPromedio = (origen.latitude + destino.latitude) / 2;
      final lngPromedio = (origen.longitude + destino.longitude) / 2;
      final puntoMedio = GeoPoint(latitude: latPromedio, longitude: lngPromedio);

      // Calcular la distancia para determinar el zoom
      final distancia = _calcularDistancia(origen.latitude, origen.longitude, destino.latitude, destino.longitude);
      double zoom = 15.0; // Zoom por defecto
      
      if (distancia > 50000) { // distancia en metros
        zoom = 10.0;
      } else if (distancia > 20000) {
        zoom = 12.0;
      } else if (distancia > 5000) {
        zoom = 14.0;
      }

      await controller.moveTo(puntoMedio);
      await controller.setZoom(zoomLevel: zoom);
      
    } catch (e) {
      debugPrint("❌ Error al centrar mapa: $e");
    }
  }

  // Callback para manejar cambios en el estado de ruta
  void _onRutaChanged(bool rutaActiva, Map<String, dynamic>? datosRuta) {
    // Asegurar que el widget esté montado y no en proceso de construcción
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      if (rutaActiva && datosRuta != null) {
        _mostrarRutaRestanteDesdeServicio(datosRuta);
      } else {
        _limpiarRutasMapa();
      }
    });
  }

  // Verificar si hay una ruta activa al cargar el mapa
  void _verificarRutaActiva() {
    if (!mounted) return;
    
    if (RutaService.instance.rutaActiva) {
      final datosRuta = RutaService.instance.datosRuta;
      if (datosRuta != null) {
        // Esperar un poco para que el mapa se inicialice completamente
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _mostrarRutaRestanteDesdeServicio(datosRuta);
          }
        });
      }
    }
  }

  // Limpiar rutas del mapa
  Future<void> _limpiarRutasMapa() async {
    try {
      await controller.removeLastRoad();
      debugPrint("🗺️ Rutas limpiadas del mapa");
    } catch (e) {
      debugPrint("❌ Error al limpiar rutas: $e");
    }
  }

  // Mostrar ruta restante usando datos del servicio
  Future<void> _mostrarRutaRestanteDesdeServicio(Map<String, dynamic> datosRuta) async {
    try {
      // Verificar que el widget esté montado
      if (!mounted) return;
      
      debugPrint("🗺️ Mostrando ruta restante desde servicio: $datosRuta");
      
      final destinoData = datosRuta['destino'] as Map<String, dynamic>;
      final esConductor = datosRuta['esConductor'] as bool? ?? true;
      
      final destino = GeoPoint(
        latitude: destinoData['lat'] as double,
        longitude: destinoData['lng'] as double,
      );

      // Esperar a que el mapa esté listo
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Verificar nuevamente que el widget esté montado
      if (!mounted) return;

      // Obtener la ubicación actual del usuario
      final ubicacionActual = await controller.myLocation();

      // Remover rutas anteriores
      await controller.removeLastRoad();

      // Dibujar la ruta desde la ubicación actual hasta el destino
      await controller.drawRoad(
        ubicacionActual,
        destino,
        roadType: RoadType.car,
        roadOption: const RoadOption(
          roadColor: Color(0xFF2196F3), // Azul para ruta restante
          roadWidth: 6,
        ),
      );

      // Agregar marcador de la ubicación actual
      await controller.addMarker(
        ubicacionActual,
        markerIcon: const MarkerIcon(
          icon: Icon(Icons.my_location, color: Color(0xFF2196F3), size: 56),
        ),
      );

      // Agregar marcador del destino
      await controller.addMarker(
        destino,
        markerIcon: const MarkerIcon(
          icon: Icon(Icons.flag, color: Color(0xFFEDCAB6), size: 56),
        ),
      );

      // Centrar el mapa para mostrar ambos puntos
      await _centrarMapaEnRuta(ubicacionActual, destino);

      // Mensaje desactivado para evitar errores de renderizado
      // El trazado de ruta funciona correctamente
      debugPrint("🚗 Ruta restante activada para ${esConductor ? 'conductor' : 'pasajero'}");

    } catch (e) {
      debugPrint("❌ Error al mostrar ruta restante desde servicio: $e");
      // Mensaje de error desactivado para evitar problemas de renderizado
    }
  }

  // ===== FUNCIONES PARA RADAR =====
  
  /// Activar/Desactivar radar de viajes
  Future<void> _toggleRadar() async {
    if (_radarActivo) {
      // Desactivar radar
      await _desactivarRadar();
    } else {
      // Activar radar
      await _activarRadar();
    }
  }

  /// Activar radar y colocar marcador en ubicación actual del centro del mapa
  Future<void> _activarRadar() async {
    try {
      setState(() {
        _mostrandoAnimacionRadar = true;
      });

      // Obtener la posición del centro del mapa (donde está mirando el usuario)
      final centroDeMapa = await controller.centerMap;
      debugPrint("🎯 Usando centro del mapa para radar: lat=${centroDeMapa.latitude}, lng=${centroDeMapa.longitude}");
      
      // Colocar marcador de radar en el centro del mapa
      await _colocarMarcadorRadar(centroDeMapa);

      setState(() {
        _radarActivo = true;
      });

      // Iniciar búsqueda progresiva de viajes (5 segundos más lento)
      await _buscarViajesProgresivamente(centroDeMapa);

      // Finalizar animación después de 2.5 segundos
      Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _mostrandoAnimacionRadar = false;
          });
        }
      });

    } catch (e) {
      debugPrint("❌ Error al activar radar: $e");
      setState(() {
        _mostrandoAnimacionRadar = false;
        _radarActivo = false;
      });
    }
  }

  /// Desactivar radar y limpiar marcadores
  Future<void> _desactivarRadar() async {
    try {
      setState(() {
        _radarActivo = false;
        _mostrandoAnimacionRadar = false;
        _viajesEnRadio = [];
        _marcadorRadar = null;
        _marcadoresViajesIds = [];
        _marcadorViajeMap = {};
      });

      // Limpiar marcadores del radar del mapa
      await _limpiarMarcadoresRadar();

    } catch (e) {
      debugPrint("❌ Error al desactivar radar: $e");
    }
  }

  /// Colocar marcador de radar movible en el mapa
  Future<void> _colocarMarcadorRadar(GeoPoint posicion) async {
    try {
      // Remover marcador anterior si existe
      if (_marcadorRadar != null) {
        await controller.removeMarker(_marcadorRadar!);
      }

      // Añadir nuevo marcador de radar
      await controller.addMarker(
        posicion,
        markerIcon: const MarkerIcon(
          iconWidget: Icon(
            Icons.radar,
            color: Colors.red,
            size: 40,
          ),
        ),
      );

      setState(() {
        _marcadorRadar = posicion;
      });

      debugPrint("📍 Marcador de radar colocado en: ${posicion.latitude}, ${posicion.longitude}");

    } catch (e) {
      debugPrint("❌ Error al colocar marcador de radar: $e");
    }
  }

  /// Buscar viajes progresivamente durante 5 segundos
  Future<void> _buscarViajesProgresivamente(GeoPoint posicion) async {
    try {
      debugPrint("🎯 Iniciando búsqueda progresiva de viajes de HOY en radio de ${_radioKm}km");

      // Limpiar marcadores de viajes anteriores
      await _limpiarMarcadoresViajes();

      setState(() {
        _viajesEnRadio = [];
        _marcadoresViajesIds = [];
      });

      // Buscar viajes más lento: 5 intervalos de 1 segundo cada uno
      const int intervalos = 5; // 5 intervalos de 1 segundo cada uno
      const duracionIntervalo = Duration(seconds: 1);

      for (int i = 0; i < intervalos; i++) {
        if (!_radarActivo) break; // Si se desactiva el radar, detener búsqueda

        // Buscar viajes en el backend (automáticamente filtra por hoy)
        final viajes = await ViajeService.buscarViajesEnRadio(
          lat: posicion.latitude,
          lng: posicion.longitude,
          radio: _radioKm,
        );

        // Añadir nuevos viajes encontrados sin notificaciones individuales
        for (final viaje in viajes) {
          final viajeId = viaje['id']?.toString();
          if (viajeId != null && !_marcadoresViajesIds.contains(viajeId)) {
            // Viaje nuevo encontrado, añadir al mapa
            await _marcarViajeEncontrado(viaje);
            
            setState(() {
              _viajesEnRadio.add(viaje);
              _marcadoresViajesIds.add(viajeId);
            });
          }
        }

        // Esperar antes del siguiente intervalo
        await Future.delayed(duracionIntervalo);
      }

      // Mostrar solo resumen final (sin notificaciones individuales)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎯 Radar completado: ${_viajesEnRadio.length} viajes de hoy en ${_radioKm}km'),
            duration: const Duration(seconds: 4),
            backgroundColor: _viajesEnRadio.isNotEmpty ? Colors.green : Colors.orange,
          ),
        );
      }

      debugPrint("✅ Búsqueda progresiva completada: ${_viajesEnRadio.length} viajes de hoy encontrados");

    } catch (e) {
      debugPrint("❌ Error en búsqueda progresiva: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error en la búsqueda de viajes'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Marcar un viaje encontrado inmediatamente en el mapa
  Future<void> _marcarViajeEncontrado(Map<String, dynamic> viaje) async {
    try {
      // Marcador para origen con ícono de vehículo
      final origenLat = viaje['origen']['lat'];
      final origenLng = viaje['origen']['lng'];
      final viajeId = viaje['id']?.toString();
      
      if (origenLat != null && origenLng != null && viajeId != null) {
        final origenPunto = GeoPoint(
          latitude: origenLat.toDouble(),
          longitude: origenLng.toDouble(),
        );

        // Determinar ícono del vehículo basado en el tipo
        IconData vehiculoIcon = Icons.directions_car;
        Color vehiculoColor = Colors.blue;
        
        final tipoVehiculo = viaje['vehiculo']?['tipo']?.toString().toLowerCase();
        switch (tipoVehiculo) {
          case 'suv':
            vehiculoIcon = Icons.drive_eta;
            vehiculoColor = Colors.green;
            break;
          case 'sedan':
            vehiculoIcon = Icons.directions_car;
            vehiculoColor = Colors.blue;
            break;
          case 'hatchback':
            vehiculoIcon = Icons.directions_car_outlined;
            vehiculoColor = Colors.purple;
            break;
          case 'pickup':
            vehiculoIcon = Icons.local_shipping;
            vehiculoColor = Colors.orange;
            break;
          default:
            vehiculoIcon = Icons.directions_car;
            vehiculoColor = Colors.blue;
        }

        await controller.addMarker(
          origenPunto,
          markerIcon: MarkerIcon(
            iconWidget: GestureDetector(
              onTap: () => _mostrarDetallesViajeRadar(viaje),
              child: Container(
                padding: const EdgeInsets.all(2), // Reducir padding
                decoration: BoxDecoration(
                  color: vehiculoColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  vehiculoIcon,
                  color: Colors.white,
                  size: 16, // Reducir tamaño del ícono significativamente
                ),
              ),
            ),
          ),
        );

        // Guardar la relación marcador-viaje
        _marcadorViajeMap[origenPunto.toString()] = viajeId;

        debugPrint("� Marcador de vehículo clickeable añadido en origen: ${viaje['origen']['nombre']}");
      }

    } catch (e) {
      debugPrint("❌ Error al marcar viaje encontrado: $e");
    }
  }

  /// Mostrar detalles de viaje encontrado por el radar
  Future<void> _mostrarDetallesViajeRadar(Map<String, dynamic> viaje) async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF854937),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getVehicleIcon(viaje['vehiculo']?['tipo']),
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Viaje encontrado por radar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${viaje['conductor']?['nombre'] ?? 'Conductor'} - ${viaje['vehiculo']?['modelo'] ?? 'Vehículo'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Contenido
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ruta
                    _buildInfoRowRadar(
                      Icons.route,
                      'Ruta',
                      '${viaje['origen']['nombre']} → ${viaje['destino']['nombre']}',
                    ),
                    const SizedBox(height: 16),

                    // Fecha y hora
                    _buildInfoRowRadar(
                      Icons.schedule,
                      'Fecha y hora',
                      _formatearFecha(viaje['fecha_ida']),
                    ),
                    const SizedBox(height: 16),

                    // Precio y plazas
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRowRadar(
                            Icons.attach_money,
                            'Precio',
                            '\$${viaje['precio']}',
                          ),
                        ),
                        Expanded(
                          child: _buildInfoRowRadar(
                            Icons.people,
                            'Plazas',
                            '${viaje['plazas_disponibles']}/${viaje['max_pasajeros']}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Vehículo
                    _buildInfoRowRadar(
                      Icons.directions_car,
                      'Vehículo',
                      '${viaje['vehiculo']?['modelo'] ?? 'N/A'} ${viaje['vehiculo']?['color'] ?? ''}',
                    ),
                    const SizedBox(height: 16),

                    // Flexibilidad
                    _buildInfoRowRadar(
                      Icons.access_time,
                      'Flexibilidad',
                      viaje['flexibilidad_salida'] ?? 'Puntual',
                    ),
                    const SizedBox(height: 16),

                    // Solo mujeres
                    if (viaje['solo_mujeres'] == true)
                      _buildInfoRowRadar(
                        Icons.female,
                        'Restricción',
                        'Solo mujeres',
                      ),

                    // Distancia desde radar
                    if (viaje['distancia_minima'] != null)
                      _buildInfoRowRadar(
                        Icons.radar,
                        'Distancia',
                        '${(viaje['distancia_minima'] / 1000).toStringAsFixed(1)} km',
                      ),

                    const SizedBox(height: 24),

                    // Botón de unirse
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _unirseViajeRadar(viaje),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF854937),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Unirse al viaje',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowRadar(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFF854937),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getVehicleIcon(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'suv':
        return Icons.drive_eta;
      case 'sedan':
        return Icons.directions_car;
      case 'hatchback':
        return Icons.directions_car_outlined;
      case 'pickup':
        return Icons.local_shipping;
      default:
        return Icons.directions_car;
    }
  }

  String _formatearFecha(dynamic fecha) {
    try {
      if (fecha == null) return 'No especificada';
      
      DateTime fechaDateTime;
      if (fecha is String) {
        fechaDateTime = DateTime.parse(fecha);
      } else if (fecha is DateTime) {
        fechaDateTime = fecha;
      } else {
        return 'Fecha inválida';
      }

      return '${fechaDateTime.day}/${fechaDateTime.month}/${fechaDateTime.year} ${fechaDateTime.hour}:${fechaDateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  Future<void> _unirseViajeRadar(Map<String, dynamic> viaje) async {
    try {
      Navigator.pop(context); // Cerrar modal

      final resultado = await ViajeService.unirseAViaje(
        viaje['id'].toString(),
        pasajeros: 1,
      );

      if (mounted) {
        if (resultado['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Solicitud enviada al conductor'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${resultado['message']}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Limpiar marcadores de radar del mapa
  Future<void> _limpiarMarcadoresRadar() async {
    try {
      // Esto requeriría una implementación específica del controlador
      // Por ahora, solo limpiamos la referencia
      debugPrint("🧹 Limpiando marcadores de radar");
    } catch (e) {
      debugPrint("❌ Error al limpiar marcadores de radar: $e");
    }
  }

  /// Limpiar marcadores de viajes del mapa
  Future<void> _limpiarMarcadoresViajes() async {
    try {
      // Esto requeriría una implementación específica del controlador
      // Por ahora, solo limpiamos las referencias
      debugPrint("🧹 Limpiando marcadores de viajes");
    } catch (e) {
      debugPrint("❌ Error al limpiar marcadores de viajes: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Mapa de BioRuta"),
            Text(
              _regionActual,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor:const Color(0xFF8D4F3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarMarcadoresViajes,
            icon: _cargandoViajes 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Actualizar viajes disponibles',
          ),
        ],
      ),
      body: Stack(
        children: [
          MapaWidget(
            controller: controller,
            onMapTap: _onMapTap,
          ),

          // Barra superior estilo Uber
          MapaUIComponents.buildBarraSuperiorUber(
            regionActual: _regionActual,
            destinoSeleccionado: direccionDestino,
            onTap: _abrirBusquedaAvanzada,
            mostrarBotonUber: true,
            origenSeleccionado: direccionOrigen,
          ),
          
          // Indicador de carga de viajes
          if (_cargandoViajes)
            Positioned(
              top: 140, // Movido más abajo para no solapar con la barra superior
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF854937),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cargando viajes...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Animación de radar
          if (_mostrandoAnimacionRadar)
            Center(
              child: RadarAnimationWidget(
                isActive: _mostrandoAnimacionRadar,
                size: 300.0, // Tamaño reducido para 500m
                color: Colors.red,
                duration: const Duration(seconds: 1), // Más lento
              ),
            ),

          // Formulario de búsqueda de viajes
          if (_mostrandoFormularioBusqueda)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con título y botón cerrar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Buscar Viajes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF854937),
                          ),
                        ),
                        IconButton(
                          onPressed: _toggleFormularioBusqueda,
                          icon: const Icon(Icons.close),
                          color: const Color(0xFF854937),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Campo "De" (Origen)
                    GestureDetector(
                      onTap: _seleccionarOrigen,
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
                              child: Text(
                                direccionOrigen ?? 'Seleccionar origen',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: direccionOrigen != null
                                      ? Colors.black87
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Campo "A" (Destino)
                    GestureDetector(
                      onTap: _seleccionarDestino,
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
                              Icons.location_on,
                              color: Color(0xFF854937),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                direccionDestino ?? 'Seleccionar destino',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: direccionDestino != null
                                      ? Colors.black87
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
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
                            Text(
                              fechaSeleccionada != null
                                  ? "${fechaSeleccionada!.day}/${fechaSeleccionada!.month}/${fechaSeleccionada!.year}"
                                  : 'Seleccionar fecha',
                              style: TextStyle(
                                fontSize: 16,
                                color: fechaSeleccionada != null
                                    ? Colors.black87
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Selector de pasajeros
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pasajeros',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF854937),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _decrementarPasajeros,
                              icon: const Icon(Icons.remove_circle_outline),
                              color: const Color(0xFF854937),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFEDCAB6)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$pasajeros',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _incrementarPasajeros,
                              icon: const Icon(Icons.add_circle_outline),
                              color: const Color(0xFF854937),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Botón de búsqueda
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _buscarViajes,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF854937),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Buscar Viajes',
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
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón de radar
          FloatingActionButton(
            heroTag: "radar",
            onPressed: _toggleRadar,
            tooltip: _radarActivo ? 'Desactivar radar' : 'Activar radar',
            backgroundColor: _radarActivo ? Colors.red : const Color(0xFF854937),
            foregroundColor: Colors.white,
            child: _mostrandoAnimacionRadar 
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.0,
                  ),
                )
              : const Icon(Icons.radar),
          ),
          const SizedBox(height: 12),
          
          FloatingActionButton(
            heroTag: "centerLocation",
            onPressed: _centrarEnMiUbicacionConRegion,
            tooltip: 'Centrar en mi ubicación',
            backgroundColor: const Color(0xFF854937),
            foregroundColor: Colors.white,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
        ],
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
      ),
    );
  }

}