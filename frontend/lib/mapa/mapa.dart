import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import '../navbar_widget.dart';
import '../models/direccion_sugerida.dart';
import '../services/ubicacion_service.dart';
import '../services/busqueda_service.dart';
import 'mapa_widget.dart';
import '../buscar/barra_busqueda_widget.dart';
import '../mis_viajes/mis_viajes_screen.dart';


class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late MapController controller;
  final TextEditingController destinoController = TextEditingController();
  int _selectedIndex = 1;
  List<DireccionSugerida> _sugerencias = [];
  bool _mostrandoSugerencias = false;
  Timer? _debounceTimer;
  String _regionActual = "Desconocida";

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

  @override
  void dispose() {
    destinoController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
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
      ),
      body: Stack(
        children: [
          MapaWidget(controller: controller),
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
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,        children: [
          FloatingActionButton(
            heroTag: "myTrips",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MisViajesScreen()),
              );
            },
            tooltip: 'Mis viajes',
            backgroundColor: const Color(0xFF854937),
            foregroundColor: Colors.white,
            child: const Icon(Icons.list_alt),
          ),
          const SizedBox(height: 12),
          
          FloatingActionButton(
            heroTag: "searchTrips",
            onPressed: () {
              Navigator.pushNamed(context, '/viajes');
            },
            tooltip: 'Buscar viajes disponibles',
            backgroundColor: const Color(0xFF854937),
            foregroundColor: Colors.white,
            child: const Icon(Icons.directions_car),
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
              Navigator.pushReplacementNamed(context, '/inicio');
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