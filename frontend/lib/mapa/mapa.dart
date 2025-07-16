import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import '../navbar_widget.dart';
import '../models/direccion_sugerida.dart';
import '../models/marcador_viaje_model.dart';
import '../services/ubicacion_service.dart';
import '../services/busqueda_service.dart';
import '../services/viaje_service.dart';
import '../services/ruta_service.dart';
import 'mapa_widget.dart';
import '../buscar/barra_busqueda_widget.dart';
import 'mapa_seleccion.dart';
import '../buscar/resultados_busqueda.dart';


class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late MapController controller;
  final TextEditingController destinoController = TextEditingController();
  int _selectedIndex = 1; // Mapa ahora está en índice 1 (Buscar)
  List<DireccionSugerida> _sugerencias = [];
  bool _mostrandoSugerencias = false;
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
  
  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();

  // Estado de la búsqueda
  bool _mostrandoFormularioBusqueda = false;

  @override
  void initState() {
    super.initState();
    controller = MapController.withUserPosition(
      trackUserLocation: const UserTrackingOption(
        enableTracking: true,
        unFollowUser: false,
      ),
    );
    
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
    if (picked != null && picked != fechaSeleccionada) {
      setState(() {
        fechaSeleccionada = picked;
      });
    }
  }

  void _incrementarPasajeros() {
    if (pasajeros < 8) {
      setState(() {
        pasajeros++;
      });
    }
  }

  void _decrementarPasajeros() {
    if (pasajeros > 1) {
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

    if (direccion != null) {
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

    if (direccion != null) {
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
    // Limpiar el callback al destruir el widget
    RutaService.instance.limpiarCallback();
    destinoController.dispose();
    _debounceTimer?.cancel();
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
      await _centrarEnMiUbicacionConRegion();
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
      double zoomNivel = UbicacionService.obtenerZoomParaRegion(region);
      
      setState(() {
        _regionActual = region;
      });

      await controller.moveTo(miPosicion);
      await controller.setZoom(zoomLevel: zoomNivel);
      
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
    }
  }

  Future<void> _buscarSugerencias(String query) async {
    if (query.length < 4) {
      setState(() {
        _sugerencias = [];
        _mostrandoSugerencias = false;
      });
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _ejecutarBusqueda(query);
    });
  }

  Future<void> _ejecutarBusqueda(String query) async {
    try {
      List<DireccionSugerida> todasLasSugerencias = [];
      
      GeoPoint? ubicacionActual = await controller.myLocation();
      String regionActual = _regionActual;

      final sugerenciasRegionales = await BusquedaService.buscarConRegion(query, regionActual);
      todasLasSugerencias.addAll(sugerenciasRegionales);

      if (todasLasSugerencias.length < 5) {
        final sugerenciasGenerales = await BusquedaService.buscarGeneral(query, 5 - todasLasSugerencias.length);
        
        for (var sugerencia in sugerenciasGenerales) {
          bool esDuplicado = todasLasSugerencias.any((existente) =>
            (existente.lat - sugerencia.lat).abs() < 0.001 &&
            (existente.lon - sugerencia.lon).abs() < 0.001
          );
          if (!esDuplicado) {
            todasLasSugerencias.add(sugerencia);
          }
        }
      }

      if (todasLasSugerencias.isNotEmpty) {
        BusquedaService.calcularDistancias(todasLasSugerencias, ubicacionActual);
        
        final regionales = todasLasSugerencias.where((s) => s.esRegional).toList()
          ..sort((a, b) => a.distancia.compareTo(b.distancia));
        
        final generales = todasLasSugerencias.where((s) => !s.esRegional).toList();
        final sugerenciasFinales = [...regionales, ...generales];
        
        if (mounted) {
          setState(() {
            _sugerencias = sugerenciasFinales.take(5).toList();
            _mostrandoSugerencias = true;
          });
        }
      }
        } catch (e) {
      debugPrint('Error al buscar sugerencias: $e');
    }
  }

  Future<void> _buscarYDibujarRuta(String destinoTexto) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔍 Buscando dirección...'),
          backgroundColor: Color(0xFF854937),
        ),
      );
    }

    final destinoPunto = await BusquedaService.buscarCoordenadas(destinoTexto);
    if (destinoPunto == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Dirección no encontrada')),
        );
      }
      return;
    }

    try {
      final origen = await controller.myLocation();

      await controller.removeLastRoad();
      await controller.drawRoad(
        origen,
        destinoPunto,
        roadType: RoadType.car,
        roadOption: const RoadOption(roadColor: Color(0xFF854937)),
      );
      await controller.moveTo(destinoPunto);
      await controller.addMarker(
        destinoPunto,
        markerIcon: const MarkerIcon(
          icon: Icon(Icons.flag, color: Color(0xFFEDCAB6), size: 56),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Ruta trazada exitosamente'),
            backgroundColor: Color(0xFF854937),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error al trazar ruta: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Ocurrió un error al trazar la ruta'),
            backgroundColor: Color(0xFF070505),
          ),
        );
      }
    }
  }

  Future<void> _cargarMarcadoresViajes() async {
    try {
      setState(() {
        _cargandoViajes = true;
      });

      final marcadoresObtenidos = await ViajeService.obtenerMarcadoresViajes();
      
      setState(() {
        _marcadoresViajes = marcadoresObtenidos;
        _cargandoViajes = false;
      });

      await _agregarMarcadoresAlMapa();
    } catch (e) {
      debugPrint('❌ Error al cargar marcadores de viajes: $e');
      setState(() {
        _cargandoViajes = false;
      });
    }
  }

  Future<void> _agregarMarcadoresAlMapa() async {
    try {
      // Limpiar marcadores existentes
      for (final punto in _marcadoresEnMapa.values) {
        await controller.removeMarker(punto);
      }
      _marcadoresEnMapa.clear();

      // Agregar nuevos marcadores
      for (final marcador in _marcadoresViajes) {
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
        backgroundColor: const Color(0xFF854937),
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
          
          // Indicador de carga de viajes
          if (_cargandoViajes)
            Positioned(
              top: 80,
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
          
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: BarraBusquedaWidget(
              controller: destinoController,
              onChanged: _buscarSugerencias,
              onSearch: () {
                final destino = destinoController.text.trim();
                if (destino.isNotEmpty) {
                  _buscarYDibujarRuta(destino);
                  setState(() {
                    _mostrandoSugerencias = false;
                  });
                }
              },
              onClear: () {
                setState(() {
                  destinoController.clear();
                  _sugerencias = [];
                  _mostrandoSugerencias = false;
                });
              },
              sugerencias: _sugerencias,
              mostrandoSugerencias: _mostrandoSugerencias,
              onSugerenciaTap: (sugerencia) {
                destinoController.text = sugerencia.displayName;
                _buscarYDibujarRuta(sugerencia.displayName);
                setState(() {
                  _mostrandoSugerencias = false;
                });
              },
            ),          ),

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
          // Botón de búsqueda de viajes
          FloatingActionButton(
            heroTag: "searchTrips",
            onPressed: _toggleFormularioBusqueda,
            tooltip: 'Buscar viajes',
            backgroundColor: const Color(0xFF854937),
            foregroundColor: Colors.white,
            child: const Icon(Icons.search),
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
      bottomNavigationBar: CustomNavbar(
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
          }        },
      ),
    );
  }

}