import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para vibración
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/navbar_con_sos_dinamico.dart';
import '../widgets/radar_animation_widget.dart';
import '../widgets/metodo_pago_modal.dart';
import '../widgets/animacion_viaje_aceptado.dart';
import '../widgets/conflicto_temporal_widgets.dart';
import '../services/notificacion_service.dart';
import '../models/direccion_sugerida.dart';
import '../models/marcador_viaje_model.dart';
import '../services/ubicacion_service.dart';
import '../services/busqueda_service.dart';
import '../services/viaje_service.dart';
import '../services/ruta_service.dart';
import '../services/user_service.dart'; // Importar UserService
import '../services/viaje_state_monitor.dart'; // Importar monitor de estados
import 'mapa_widget.dart';
import 'mapa_ui_components_v2.dart'; // Importar componentes de UI
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
  int _selectedIndex = 1; // Mapa está en índice 1 cuando showSOS = true
  Timer? _debounceTimer;
  Timer? _radarTimer; // Timer para controlar el radar
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

  // Variables para notificaciones de viaje aceptado
  Timer? _notificacionTimer;
  List<String> _notificacionesProcesadas = []; // Para evitar mostrar la misma animación múltiples veces

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
    
    // Configurar listener para notificaciones de viaje aceptado
    _configurarNotificacionesViajeAceptado();
    
    // Inicializar monitor de estados de viajes
    ViajeStateMonitor.instance.iniciarMonitoreo();
    
    _inicializarUbicacion();
    _cargarMarcadoresViajes();
    
    // Verificar si hay una ruta activa después de que el widget esté construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarRutaActiva();
    });
  }

  // ===== MÉTODOS PARA FUNCIONALIDAD DE BÚSQUEDA =====

  /// Configurar notificaciones para mostrar animación cuando se acepta un viaje
  void _configurarNotificacionesViajeAceptado() {
    try {
      // Iniciar polling más frecuente para detectar aceptaciones rápidamente (cada 3 segundos)
      _notificacionTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _verificarNotificacionesViajeAceptado();
      });
      
      print('🎧 Sistema de notificaciones de viaje aceptado activado (polling cada 3s)');
    } catch (e) {
      print('Error configurando notificaciones de viaje aceptado: $e');
    }
  }

  /// Verificar si hay nuevas notificaciones de viaje aceptado
  Future<void> _verificarNotificacionesViajeAceptado() async {
    if (!mounted) return;
    
    try {
      final resultado = await NotificacionService.obtenerNotificacionesPendientes();
      
      if (resultado['success'] == true) {
        final notificaciones = resultado['data'] as List;
        
        for (final notificacion in notificaciones) {
          // Buscar notificaciones específicas de ride_accepted con flag de animación
          if (notificacion['tipo'] == 'ride_accepted' && 
              notificacion['datos']?['mostrarAnimacion'] == true) {
            
            final notifId = notificacion['_id'].toString();
            
            // Verificar que no hayamos procesado esta notificación antes
            if (!_notificacionesProcesadas.contains(notifId)) {
              _notificacionesProcesadas.add(notifId);
              
              print('🎉 ¡Viaje aceptado detectado! Mostrando animación...');
              
              // Mostrar la animación
              _mostrarAnimacionViajeAceptado();
              
              // Marcar como leída para que no se muestre de nuevo
              await NotificacionService.marcarComoLeida(notifId);
              
              print('✅ Animación de viaje aceptado mostrada para notificación: $notifId');
              
              // Mostrar también un SnackBar informativo
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🚗 ${notificacion['mensaje'] ?? 'Tu viaje fue aceptado'}'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'Ver',
                      textColor: Colors.white,
                      onPressed: () {
                        // Aquí se puede navegar a la pantalla de viaje o detalles
                      },
                    ),
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error verificando notificaciones de viaje aceptado: $e');
    }
  }

  /// Mostrar la animación de viaje aceptado
  void _mostrarAnimacionViajeAceptado() {
    if (!mounted) return;
    
    RideAcceptedHelper.show(
      context,
      onComplete: () {
        print('🎉 Animación de viaje aceptado completada');
      },
    );
  }

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
          soloMujeres: soloMujeres, // Pasar el parámetro de filtro
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
          origenSeleccionado: null, // No hay origen previo cuando seleccionamos origen
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
    // Si ya tenemos origen, crear DireccionSugerida para pasar al destino
    DireccionSugerida? origenSeleccionado;
    if (direccionOrigen != null && origenLat != null && origenLng != null) {
      origenSeleccionado = DireccionSugerida(
        displayName: direccionOrigen!,
        lat: origenLat!,
        lon: origenLng!,
        esOrigen: true,
      );
    }
    
    final direccion = await Navigator.push<DireccionSugerida>(
      context,
      MaterialPageRoute(
        builder: (context) => MapaSeleccionPage(
          tituloSeleccion: 'Seleccionar destino',
          esOrigen: false,
          origenSeleccionado: origenSeleccionado,
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
    _radarTimer?.cancel();
    _notificacionTimer?.cancel(); // Cancelar timer de notificaciones
    
    // Detener monitor de estados de viajes
    ViajeStateMonitor.instance.detenerMonitoreo();
    
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

      // Agregar timestamp para evitar caché
      final marcadoresObtenidos = await ViajeService.obtenerMarcadoresViajes();
      
      if (!mounted) return; // Verificar nuevamente después de la operación async
      
      print('🔢 Marcadores obtenidos: ${marcadoresObtenidos.length}');
      for (final marcador in marcadoresObtenidos) {
        print('🔢 Viaje ${marcador.id}: ${marcador.detallesViaje.plazasDisponibles} plazas disponibles');
      }
      
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
              size: 72,
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
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header con degradado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF854937),
                    const Color(0xFF6B3B2D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Indicador para arrastrar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Título y precio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Viaje Disponible',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '\$${marcador.detallesViaje.precio.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Ruta principal
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Origen
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Origen',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                marcador.origen.nombre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Flecha
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        // Destino
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Destino',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                marcador.destino.nombre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Contenido principal
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información del conductor
                    if (marcador.detallesViaje.conductor != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2EEED),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF854937),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Conductor',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    marcador.detallesViaje.conductor!.nombre,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B3B2D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Información del viaje en tarjetas
                    const Text(
                      'Detalles del Viaje',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B3B2D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildDetailCard(
                      icon: Icons.calendar_today,
                      title: 'Fecha',
                      value: '${marcador.detallesViaje.fecha.day}/${marcador.detallesViaje.fecha.month}/${marcador.detallesViaje.fecha.year}',
                      color: Colors.blue,
                    ),
                    
                    _buildDetailCard(
                      icon: Icons.access_time,
                      title: 'Hora',
                      value: marcador.detallesViaje.hora,
                      color: Colors.orange,
                    ),
                    
                    _buildDetailCard(
                      icon: Icons.airline_seat_recline_normal,
                      title: 'Plazas disponibles',
                      value: '${marcador.detallesViaje.plazasDisponibles} asientos',
                      color: Colors.green,
                    ),
                    
                    if (marcador.detallesViaje.vehiculo != null)
                      _buildDetailCard(
                        icon: Icons.directions_car,
                        title: 'Vehículo',
                        value: '${marcador.detallesViaje.vehiculo!.modelo} (${marcador.detallesViaje.vehiculo!.color})',
                        color: const Color(0xFF854937),
                      ),
                  ],
                ),
              ),
            ),
            
            // Botón de acción
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _unirseAlViaje(marcador),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF854937),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Unirse al Viaje',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B3B2D),
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
      
      // Mostrar modal de selección de método de pago
      final metodoPagoResult = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => MetodoPagoModal(
          precio: marcador.detallesViaje.precio,
          viajeOrigen: marcador.origen.nombre,
          viajeDestino: marcador.destino.nombre,
          onPagoSeleccionado: (metodoPago, datosAdicionales, mensaje) {
            Navigator.pop(context, {
              'metodoPago': metodoPago,
              'datosAdicionales': datosAdicionales,
              'mensaje': mensaje,
            });
          },
        ),
      );

      if (metodoPagoResult == null) {
        // Usuario canceló la selección de pago
        return;
      }

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enviando solicitud con información de pago...'),
            backgroundColor: Color(0xFF854937),
          ),
        );
      }

      // Enviar solicitud con información de pago
      final resultado = await ViajeService.unirseAViajeConPago(
        marcador.id,
        metodoPagoResult['metodoPago'],
        metodoPagoResult['datosAdicionales'],
        mensaje: metodoPagoResult['mensaje'],
      );

      if (mounted) {
        // Mensaje específico para el nuevo flujo de notificaciones con pago
        String mensaje = resultado['message'] ?? 'Solicitud enviada';
        
        if (resultado['success'] == true) {
          mensaje = 'Solicitud enviada al conductor con información de pago. Espera su respuesta en tus notificaciones.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensaje),
              backgroundColor: const Color(0xFF854937),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // Verificar si es un conflicto temporal
          final tipoConflicto = _detectarTipoConflicto(mensaje);
          
          print('🔥 DEBUG (unirseAlViaje) - Respuesta completa del backend: $resultado');
          print('🔥 DEBUG (unirseAlViaje) - Mensaje de error recibido: "$mensaje"');
          
          if (tipoConflicto != null) {
            print('✅ DEBUG (unirseAlViaje) - Mostrando dialog de conflicto temporal');
            // Mostrar dialog mejorado para conflictos temporales
            showDialog(
              context: context,
              builder: (context) => ConflictoTemporalDialog(
                tipoConflicto: tipoConflicto,
                mensaje: mensaje,
                detallesConflicto: {
                  'viajeConflicto': marcador.id,
                  if (resultado.containsKey('tiempoDisponible'))
                    'tiempoDisponible': resultado['tiempoDisponible'],
                  if (resultado.containsKey('tiempoNecesario'))
                    'tiempoNecesario': resultado['tiempoNecesario'],
                },
              ),
            );
          } else {
            print('❌ DEBUG (unirseAlViaje) - Mostrando SnackBar normal para error: "$mensaje"');
            // Mostrar SnackBar normal para otros errores
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensaje),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
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

      // Iniciar búsqueda progresiva de viajes (2 segundos total)
      await _buscarViajesProgresivamente(centroDeMapa);

      // Finalizar animación y desactivar radar después de 2 segundos
      _radarTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) {
          setState(() {
            _mostrandoAnimacionRadar = false;
            _radarActivo = false; // Desactivar automáticamente
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
      // Cancelar el timer si está activo
      _radarTimer?.cancel();
      _radarTimer = null;
      
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

      // Buscar viajes más rápido: 2 intervalos de 1 segundo cada uno
      const int intervalos = 2; // 2 intervalos de 1 segundo = 2 segundos total
      const duracionIntervalo = Duration(milliseconds: 1000);

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
            content: Text('🎯 Radar completado: ${_viajesEnRadio.length} viajes de hoy en ${_radioKm} km'),
            duration: const Duration(seconds: 4),
            backgroundColor: _viajesEnRadio.isNotEmpty ? Colors.green : Colors.orange,
          ),
        );

        // Vibrar si se encontraron viajes
        if (_viajesEnRadio.isNotEmpty) {
          try {
            HapticFeedback.heavyImpact(); // Vibración fuerte
          } catch (e) {
            debugPrint("⚠️ No se pudo activar vibración: $e");
          }
        }
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
                padding: const EdgeInsets.all(4), // Reducir padding para icono más pequeño
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
                  size: 24, // Tamaño reducido para marcadores del radar
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
        return Icons.drive_eta;
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
          // Verificar si es un conflicto temporal
          final message = resultado['message'] ?? 'Error desconocido';
          
          print('🔥 DEBUG - Respuesta completa del backend: $resultado');
          print('🔥 DEBUG - Mensaje de error recibido: "$message"');
          
          final tipoConflicto = _detectarTipoConflicto(message);
          
          if (tipoConflicto != null) {
            print('✅ DEBUG - Mostrando dialog de conflicto temporal');
            // Mostrar dialog mejorado para conflictos temporales
            showDialog(
              context: context,
              builder: (context) => ConflictoTemporalDialog(
                tipoConflicto: tipoConflicto,
                mensaje: message,
                detallesConflicto: {
                  'viajeConflicto': viaje['id'].toString(),
                  if (resultado.containsKey('tiempoDisponible'))
                    'tiempoDisponible': resultado['tiempoDisponible'],
                  if (resultado.containsKey('tiempoNecesario'))
                    'tiempoNecesario': resultado['tiempoNecesario'],
                },
              ),
            );
          } else {
            print('❌ DEBUG - Mostrando SnackBar normal para error: "$message"');
            // Mostrar SnackBar normal para otros errores
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ $message'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
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

  String? _detectarTipoConflicto(String mensaje) {
    final mensajeLower = mensaje.toLowerCase();
    
    print('🔍 DEBUG - Detectando tipo de conflicto para mensaje: "$mensaje"');
    
    // Detectar conflicto temporal/solapamiento
    if (mensajeLower.contains('conflicto temporal') || 
        mensajeLower.contains('se solapa') ||
        mensajeLower.contains('solapamiento') ||
        mensajeLower.contains('viaje existente') ||
        mensajeLower.contains('nuevo viaje se solapa')) {
      print('✅ DEBUG - Detectado como: solapamiento_temporal');
      return 'solapamiento_temporal';
    }
    
    // Detectar conductor unido a viaje
    if (mensajeLower.contains('no puedes publicar') ||
        mensajeLower.contains('conductor') && mensajeLower.contains('unido') ||
        mensajeLower.contains('horario de un viaje') ||
        mensajeLower.contains('estás unido')) {
      print('✅ DEBUG - Detectado como: conductor_unido_a_viaje');
      return 'conductor_unido_a_viaje';
    }
    
    // Detectar tiempo de traslado insuficiente
    if (mensajeLower.contains('tiempo insuficiente') ||
        mensajeLower.contains('traslado') ||
        mensajeLower.contains('no hay tiempo suficiente') ||
        mensajeLower.contains('tiempo de viaje')) {
      print('✅ DEBUG - Detectado como: tiempo_traslado_insuficiente');
      return 'tiempo_traslado_insuficiente';
    }
    
    print('❌ DEBUG - No se detectó tipo de conflicto específico');
    return null;
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
          // Botón de refresh
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

          // Barra superior de búsqueda usando MapaUIComponents
          MapaUIComponents.buildBarraSuperiorUber(
            regionActual: _regionActual,
            destinoSeleccionado: direccionDestino,
            origenSeleccionado: direccionOrigen,
            onTap: _abrirBusquedaAvanzada,
            mostrarBotonUber: true,
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

          // Botón de radar usando MapaUIComponents
          MapaUIComponents.buildBotonRadar(
            radarActivo: _radarActivo,
            onPressed: _toggleRadar,
          ),
          
          // Botón de ubicación actual usando MapaUIComponents
          MapaUIComponents.buildBotonUbicacionActual(
            onPressed: _centrarEnMiUbicacionConRegion,
          ),
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