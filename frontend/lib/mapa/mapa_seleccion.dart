import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/direccion_sugerida.dart';
import '../services/ubicacion_service.dart';
import '../services/busqueda_service.dart';
import '../mapa/mapa_widget.dart';
import '../buscar/barra_busqueda_widget.dart';

class MapaSeleccionPage extends StatefulWidget {
  final String tituloSeleccion;
  final bool esOrigen;
  final DireccionSugerida? origenSeleccionado; // Para calcular tiempo cuando es destino

  const MapaSeleccionPage({
    super.key,
    required this.tituloSeleccion,
    required this.esOrigen,
    this.origenSeleccionado, // Opcional: solo se usa cuando esOrigen == false
  });

  @override
  State<MapaSeleccionPage> createState() => _MapaSeleccionPageState();
}

class _MapaSeleccionPageState extends State<MapaSeleccionPage> {
  late MapController controller;
  final TextEditingController busquedaController = TextEditingController();
  List<DireccionSugerida> _sugerencias = [];
  bool _mostrandoSugerencias = false;
  Timer? _debounceTimer;
  String _regionActual = "Desconocida";
  DireccionSugerida? _ubicacionSeleccionada;
  bool _marcadorColocado = false;

  @override
  void initState() {
    super.initState();
    controller = MapController.withUserPosition(
      trackUserLocation: const UserTrackingOption(
        enableTracking: true,
        unFollowUser: false,
      ),
    );
    _inicializarUbicacion();
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
    if (status == PermissionStatus.granted) {
      await _centrarEnMiUbicacion();
    }
  }
  Future<void> _centrarEnMiUbicacion() async {
    try {
      GeoPoint miPosicion = await controller.myLocation();
      String region = await BusquedaService.identificarRegion(miPosicion);
      double zoomNivel = UbicacionService.obtenerZoomParaRegion(region);
      
      setState(() {
        _regionActual = region;
      });

      await controller.moveTo(miPosicion);
      await controller.setZoom(zoomLevel: zoomNivel);
      
      // Si es origen, automáticamente seleccionar la ubicación actual
      if (widget.esOrigen) {
        _seleccionarUbicacionActual();
      }
    } catch (e) {
      debugPrint("❌ Error al centrar en ubicación: $e");
    }
  }
  Future<void> _seleccionarUbicacionActual() async {
    try {
      GeoPoint miPosicion = await controller.myLocation();
      final ubicacionActual = DireccionSugerida(
        displayName: "Mi ubicación actual",
        lat: miPosicion.latitude,
        lon: miPosicion.longitude,
      );
      
      await _colocarMarcador(miPosicion, "Mi ubicación actual");
      
      setState(() {
        _ubicacionSeleccionada = ubicacionActual;
        busquedaController.text = "Mi ubicación actual";
      });
    } catch (e) {
      debugPrint("❌ Error al obtener ubicación actual: $e");
    }
  }

  Future<void> _buscarSugerencias(String query) async {
    if (query.length < 3) {
      setState(() {
        _sugerencias = [];
        _mostrandoSugerencias = false;
      });
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _ejecutarBusqueda(query);
    });
  }
  Future<void> _ejecutarBusqueda(String query) async {
    try {
      List<DireccionSugerida> todasLasSugerencias = [];
      
      String regionActual = _regionActual;

      // Pasar información sobre si es origen o destino para el cálculo de tiempo
      final sugerenciasRegionales = await BusquedaService.buscarConRegion(
        query, 
        regionActual, 
        esOrigen: widget.esOrigen
      );
      todasLasSugerencias.addAll(sugerenciasRegionales);

      if (todasLasSugerencias.length < 5) {
        final sugerenciasGenerales = await BusquedaService.buscarGeneral(
          query, 
          5 - todasLasSugerencias.length,
          esOrigen: widget.esOrigen
        );
        
        for (var sugerencia in sugerenciasGenerales) {
          bool esDuplicado = todasLasSugerencias.any((existente) =>
            (existente.lat - sugerencia.lat).abs() < 0.001 &&
            (existente.lon - sugerencia.lon).abs() < 0.001
          );
          if (!esDuplicado) {
            todasLasSugerencias.add(sugerencia);
          }
        }
      }      if (todasLasSugerencias.isNotEmpty) {
        GeoPoint ubicacionActual = await controller.myLocation();
        
        // Usar función apropiada según si tenemos origen seleccionado
        if (widget.origenSeleccionado != null) {
          BusquedaService.calcularDistanciasConOrigen(
            todasLasSugerencias, 
            ubicacionActual,
            widget.origenSeleccionado
          );
        } else {
          BusquedaService.calcularDistancias(todasLasSugerencias, ubicacionActual);
        }
        
        // Separar por tipo y ordenar por relevancia
        final regionales = todasLasSugerencias.where((s) => s.esRegional).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName)); // Orden alfabético
        
        final generales = todasLasSugerencias.where((s) => !s.esRegional).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName)); // Orden alfabético
        
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

  Future<void> _seleccionarSugerencia(DireccionSugerida sugerencia) async {
    setState(() {
      _ubicacionSeleccionada = sugerencia;
      busquedaController.text = sugerencia.displayName;
      _mostrandoSugerencias = false;
    });

    final punto = GeoPoint(latitude: sugerencia.lat, longitude: sugerencia.lon);
    await controller.moveTo(punto);
    await _colocarMarcador(punto, sugerencia.displayName);
  }

  Future<void> _colocarMarcador(GeoPoint punto, String descripcion) async {
    try {
      // Limpiar marcadores previos
      if (_marcadorColocado) {
        await controller.removeMarker(punto);
      }

      await controller.addMarker(
        punto,
        markerIcon: MarkerIcon(
          icon: Icon(
            widget.esOrigen ? Icons.my_location : Icons.place,
            color: widget.esOrigen ? const Color(0xFF8D4F3A) : const Color(0xFFEDCAB6),
            size: 56,
          ),
        ),
      );      setState(() {
        _marcadorColocado = true;
      });
    } catch (e) {
      debugPrint("❌ Error al colocar marcador: $e");
    }
  }

  void _confirmarSeleccion() {
    if (_ubicacionSeleccionada != null) {
      Navigator.pop(context, _ubicacionSeleccionada);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una ubicación'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    busquedaController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tituloSeleccion),
            Text(
              _regionActual,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF8D4F3A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_ubicacionSeleccionada != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _confirmarSeleccion,
              tooltip: 'Confirmar selección',
            ),
        ],
      ),
      body: Stack(
        children: [
          MapaWidget(controller: controller),
          
          // Barra de búsqueda
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: BarraBusquedaWidget(
              controller: busquedaController,
              onChanged: _buscarSugerencias,
              onSearch: () {
                final busqueda = busquedaController.text.trim();
                if (busqueda.isNotEmpty) {
                  setState(() {
                    _mostrandoSugerencias = false;
                  });
                }
              },
              onClear: () {
                setState(() {
                  busquedaController.clear();
                  _sugerencias = [];
                  _mostrandoSugerencias = false;
                  _ubicacionSeleccionada = null;
                });
              },
              sugerencias: _sugerencias,
              mostrandoSugerencias: _mostrandoSugerencias,
              onSugerenciaTap: _seleccionarSugerencia,
            ),
          ),          // Botón de centrar en mi ubicación
          Positioned(
            top: 80,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'centrar',
              onPressed: _centrarEnMiUbicacion,
              tooltip: 'Centrar en mi ubicación',
              backgroundColor: const Color(0xFF8D4F3A),
              foregroundColor: Colors.white,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Botón de confirmación flotante
          if (_ubicacionSeleccionada != null)            Positioned(
              bottom: 20, // Más espacio desde el fondo
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8D4F3A),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _ubicacionSeleccionada!.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirmarSeleccion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEDCAB6),
                          foregroundColor: const Color(0xFF8D4F3A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          widget.esOrigen ? 'Confirmar Origen' : 'Confirmar Destino',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),        ],
      ),
    );
  }
}
