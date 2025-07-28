import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/viaje_service.dart';
import '../models/viaje_model.dart';
import '../widgets/navbar_con_sos_dinamico.dart';
import '../widgets/metodo_pago_modal.dart';

class ResultadosBusquedaScreen extends StatefulWidget {
  final double origenLat;
  final double origenLng;
  final double destinoLat;
  final double destinoLng;
  final String fechaViaje;
  final int pasajeros;
  final String origenTexto;
  final String destinoTexto;
  final bool soloMujeres; // Nuevo parámetro para filtro de género

  const ResultadosBusquedaScreen({
    super.key,
    required this.origenLat,
    required this.origenLng,
    required this.destinoLat,
    required this.destinoLng,
    required this.fechaViaje,
    required this.pasajeros,
    required this.origenTexto,
    required this.destinoTexto,
    this.soloMujeres = false, // Por defecto false
  });

  @override
  State<ResultadosBusquedaScreen> createState() => _ResultadosBusquedaScreenState();
}

class _ResultadosBusquedaScreenState extends State<ResultadosBusquedaScreen> {
  int _selectedIndex = 1; // Mapa está en índice 1
  List<ViajeProximidad> _viajes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _buscarViajes();
  }

  Future<void> _buscarViajes() async {
    try {
      setState(() {
        _cargando = true;
        _error = null;
      });      final viajes = await ApiService.buscarViajesPorProximidad(
        origenLat: widget.origenLat,
        origenLng: widget.origenLng,
        destinoLat: widget.destinoLat,
        destinoLng: widget.destinoLng,
        fechaViaje: widget.fechaViaje,
        pasajeros: widget.pasajeros,
        soloMujeres: widget.soloMujeres, // Usar el parámetro soloMujeres
      );

      // Debug: Verificar datos del conductor
      for (int i = 0; i < viajes.length; i++) {
        print('🚗 Viaje ${i + 1}:');
        print('  - ID: "${viajes[i].id}"');
        print('  - ID length: ${viajes[i].id.length}');
        print('  - RUT: ${viajes[i].usuarioRut}');
        print('  - Conductor: ${viajes[i].conductor?.nombre ?? "null"}');
        print('  - Precio: ${viajes[i].precio}');
        print('  - Origen: ${viajes[i].origen.nombre}');
        print('  - Destino: ${viajes[i].destino.nombre}');
      }

      // Ordenar por distancia total (origen + destino)
      viajes.sort((a, b) {
        final distanciaA = a.distancias.origenMetros + a.distancias.destinoMetros;
        final distanciaB = b.distancias.origenMetros + b.distancias.destinoMetros;
        return distanciaA.compareTo(distanciaB);
      });

      setState(() {
        _viajes = viajes;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _unirseAlViaje(ViajeProximidad viaje) async {
    try {
      print('🚗 Datos del viaje seleccionado:');
      print('  - ID: "${viaje.id}"');
      print('  - ID length: ${viaje.id.length}');
      print('  - ID isEmpty: ${viaje.id.isEmpty}');
      print('  - Origen: ${viaje.origen.nombre}');
      print('  - Destino: ${viaje.destino.nombre}');
      print('  - Precio: ${viaje.precio}');

      // Verificar que el ID no esté vacío
      if (viaje.id.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: ID del viaje no válido'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Mostrar modal de selección de método de pago
      final metodoPagoResult = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => MetodoPagoModal(
          precio: viaje.precio,
          viajeOrigen: viaje.origen.nombre,
          viajeDestino: viaje.destino.nombre,
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
        viaje.id,
        metodoPagoResult['metodoPago'],
        metodoPagoResult['datosAdicionales'],
        mensaje: metodoPagoResult['mensaje'],
      );

      if (mounted) {
        // Mensaje específico para el nuevo flujo de notificaciones con pago
        String mensaje = resultado['message'] ?? 'Solicitud enviada';
        if (resultado['success'] == true) {
          mensaje = 'Solicitud enviada al conductor con información de pago. Espera su respuesta en tus notificaciones.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: resultado['success'] == true 
                ? const Color(0xFF854937) 
                : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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

  // Función para abrir Google Maps con navegación al origen del viaje
  Future<void> _abrirGoogleMaps(ViajeProximidad viaje) async {
    try {
      final lat = viaje.origen.latitud;
      final lng = viaje.origen.longitud;
      final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir Google Maps'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al abrir Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al abrir Google Maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Función para abrir Waze con navegación al origen del viaje
  Future<void> _abrirWaze(ViajeProximidad viaje) async {
    try {
      final lat = viaje.origen.latitud;
      final lng = viaje.origen.longitud;
      final url = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir Waze. ¿Está instalado?'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al abrir Waze: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al abrir Waze'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF854937),
        foregroundColor: Colors.white,
        title: const Text(
          'Resultados de Búsqueda',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _buscarViajes,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavbarConSOSDinamico(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == _selectedIndex) return;
          
          setState(() {
            _selectedIndex = index;
          });
          
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

  Widget _buildBody() {
    if (_cargando) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF854937),
            ),
            SizedBox(height: 16),
            Text(
              'Buscando viajes...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF070505),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xFF854937),
              ),
              const SizedBox(height: 16),
              const Text(
                'Error al buscar viajes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF070505),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF070505).withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _buscarViajes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF854937),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_viajes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off,
                size: 64,
                color: Color(0xFF854937),
              ),
              const SizedBox(height: 16),
              const Text(
                'No se encontraron viajes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF070505),
                ),
              ),              const SizedBox(height: 8),
              Text(
                'No hay viajes disponibles en un radio de 10 km de tu origen y destino para la fecha seleccionada.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF070505).withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF854937),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Buscar de nuevo'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Encabezado con información de búsqueda
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF070505).withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: Color(0xFF854937),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_viajes.length} viaje(s) encontrado(s)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF070505),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.my_location,
                    color: Color(0xFF854937),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.origenTexto,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF070505),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.place,
                    color: Color(0xFF854937),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.destinoTexto,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF070505),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF854937),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.fechaViaje,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF070505),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.people,
                    color: Color(0xFF854937),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.pasajeros} pasajero(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF070505),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Lista de resultados
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _viajes.length,
            itemBuilder: (context, index) {
              return _buildViajeCard(_viajes[index], index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildViajeCard(ViajeProximidad viaje, int posicion) {
    final distanciaTotal = viaje.distancias.origenMetros + viaje.distancias.destinoMetros;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: posicion == 1 
                ? const Color(0xFF854937) 
                : const Color(0xFFEDCAB6),
            width: posicion == 1 ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con posición y precio
              Row(
                children: [
                  // Número de posición
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: posicion == 1 
                          ? const Color(0xFF854937) 
                          : const Color(0xFFEDCAB6),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text(
                        '$posicion',
                        style: TextStyle(
                          color: posicion == 1 ? Colors.white : const Color(0xFF070505),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Información del conductor
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [                        Text(
                          'Conductor: ${viaje.conductor?.nombre ?? viaje.usuarioRut}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF070505),
                          ),
                        ),
                        Text(
                          'Vehículo: ${viaje.vehiculoPatente}',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF070505).withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Precio
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF854937),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '\$${viaje.precio.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Origen y destino
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.my_location, color: Color(0xFF854937), size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                viaje.origen.nombre,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.place, color: Color(0xFF854937), size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                viaje.destino.nombre,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Fecha y hora
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Color(0xFF854937)),
                          const SizedBox(width: 4),
                          Text(
                            viaje.fechaIdaFormateada,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Color(0xFF854937)),
                          const SizedBox(width: 4),
                          Text(
                            viaje.horaIda,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Información de distancias
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDCAB6).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_walk, color: Color(0xFF854937), size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Distancias de caminata:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF070505),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDistanciaChip(
                          'Al origen',
                          '${viaje.distancias.origenMetros}m',
                          viaje.distancias.origenMetros <= 250 
                              ? Colors.green 
                              : viaje.distancias.origenMetros <= 400 
                                  ? Colors.orange 
                                  : Colors.red,
                        ),
                        _buildDistanciaChip(
                          'Al destino',
                          '${viaje.distancias.destinoMetros}m',
                          viaje.distancias.destinoMetros <= 250 
                              ? Colors.green 
                              : viaje.distancias.destinoMetros <= 400 
                                  ? Colors.orange 
                                  : Colors.red,
                        ),
                        _buildDistanciaChip(
                          'Total',
                          '${distanciaTotal}m',
                          distanciaTotal <= 500 
                              ? Colors.green 
                              : distanciaTotal <= 800 
                                  ? Colors.orange 
                                  : Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Información adicional
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${viaje.plazasDisponibles}/${viaje.maxPasajeros} asientos',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF070505),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  if (viaje.soloMujeres)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.pink.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.female, size: 14, color: Colors.pink),
                          SizedBox(width: 4),
                          Text(
                            'Solo mujeres',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.pink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Botones de navegación
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF854937).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF854937).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.navigation, color: Color(0xFF854937), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Navegar al punto de encuentro:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF854937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _abrirGoogleMaps(viaje),
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text(
                              'Google Maps',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _abrirWaze(viaje),
                            icon: const Icon(Icons.navigation, size: 16),
                            label: const Text(
                              'Waze',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Botón de acción principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _unirseAlViaje(viaje),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF854937),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Ver Detalles y Solicitar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistanciaChip(String label, String distancia, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            distancia,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
