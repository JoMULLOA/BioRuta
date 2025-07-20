import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/viaje_service.dart';
import '../services/pago_service.dart';
import '../services/notificacion_service.dart';
import '../models/viaje_model.dart';
import '../widgets/navbar_con_sos_dinamico.dart';
import 'detalle_viaje_conductor_screen.dart';
import 'detalle_viaje_pasajero_screen.dart';
import 'solicitudes_pasajeros_modal.dart';

class MisViajesScreen extends StatefulWidget {
  const MisViajesScreen({super.key});

  @override
  State<MisViajesScreen> createState() => _MisViajesScreenState();
}

class _MisViajesScreenState extends State<MisViajesScreen> 
    with SingleTickerProviderStateMixin {
  List<Viaje> viajesCreados = [];
  List<Viaje> viajesUnidos = [];
  bool cargando = true;
  int _selectedIndex = 0; // Mis viajes ahora está en índice 0
  int numeroSolicitudesPendientes = 0;
  late TabController _tabController;
  
  // Variable para rastrear el listener
  late VoidCallback _tabListener;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1); // Iniciar en "Viajes unidos"
    
    // Crear y asignar el listener
    _tabListener = () {
      if (mounted) {
        setState(() {}); // Actualizar el FAB cuando cambie de pestaña
      }
    };
    _tabController.addListener(_tabListener);
    
    _cargarViajes();
    _cargarSolicitudesPendientes();
  }

  @override
  void dispose() {
    // Remover listener antes de dispose para evitar llamadas a setState después del dispose
    _tabController.removeListener(_tabListener);
    _tabController.dispose();
    super.dispose();
  }

Future<void> _cargarViajes() async {
  try {
    if (mounted) {
      setState(() {
        cargando = true;
      });
    }

    // Cargar viajes usando el método obtenerMisViajes
    final List<Viaje> viajes = await ViajeService.obtenerMisViajes();
    
    print('🔍 Total viajes recibidos: ${viajes.length}');
    for (int i = 0; i < viajes.length; i++) {
      final viaje = viajes[i];
      print('   Viaje $i: esCreador=${viaje.esCreador}, esUnido=${viaje.esUnido}');
    }

    if (mounted) {
      setState(() {
        // Separar viajes creados de viajes a los que se unió usando las nuevas propiedades
        viajesCreados = viajes.where((v) => v.esCreador == true).toList();
        viajesUnidos = viajes.where((v) => v.esUnido == true).toList();
        cargando = false;
      });
    }
    
    print('📝 Viajes creados: ${viajesCreados.length}');
    print('🚗 Viajes unidos: ${viajesUnidos.length}');
  } catch (e) {
    if (mounted) {
      setState(() {
        cargando = false;
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar viajes: $e')),
      );
    }
  }
}

Future<void> _cargarSolicitudesPendientes() async {
  try {
    final numero = await NotificacionService.obtenerNumeroNotificacionesPendientes();
    if (mounted) {
      setState(() {
        numeroSolicitudesPendientes = numero;
      });
    }
  } catch (e) {
    print('Error al cargar solicitudes pendientes: $e');
  }
}

void _mostrarSolicitudesPasajeros() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SolicitudesPasajerosModal(
      onSolicitudProcesada: () {
        // Verificar que el widget sigue montado antes de recargar
        if (mounted) {
          // Recargar solicitudes pendientes para actualizar el badge
          _cargarSolicitudesPendientes();
          
          // Recargar viajes para mostrar los cambios en las listas
          _cargarViajes();
          
          // Notificar al sistema global que los marcadores deben actualizarse
          // Esto permitirá que el mapa se entere cuando se regrese a esa pantalla
          debugPrint('📱 Solicitud procesada - estado de viajes actualizado');
        }
      },
    ),
  ).then((_) {
    // Recargar solicitudes al cerrar el modal solo si el widget sigue montado
    if (mounted) {
      _cargarSolicitudesPendientes();
    }
  });
}

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }

    switch (index) {
      case 0:
        // Ya estamos en mis viajes, no hacer nada
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
        Navigator.pushReplacementNamed(context, '/perfil'); // Perfil en índice 5 cuando no hay SOS
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: const Text('Mis Viajes'),
        backgroundColor: const Color(0xFF8D4F3A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Quitar el botón de volver atrás
        bottom: cargando
            ? null
            : TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFFEDCAB6),
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(text: 'Mis Publicaciones'),
                  Tab(text: 'Viajes Unidos'),
                ],
              ),
      ),
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF854937)),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildViajesCreados(),
                _buildViajesUnidos(),
              ],
            ),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: NavbarConSOSDinamico(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    // Solo mostrar el FAB en la pestaña "Mis Publicaciones" y si hay viajes creados
    return _tabController.index == 0 && viajesCreados.isNotEmpty
        ? FloatingActionButton.extended(
            onPressed: _mostrarSolicitudesPasajeros,
            backgroundColor: const Color(0xFF854937),
            foregroundColor: Colors.white,
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (numeroSolicitudesPendientes > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$numeroSolicitudesPendientes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: Text(
              'Solicitudes${numeroSolicitudesPendientes > 0 ? ' ($numeroSolicitudesPendientes)' : ''}',
            ),
          )
        : null;
  }

  Widget _buildViajesCreados() {
    if (viajesCreados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No has publicado ningún viaje',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Publica tu primer viaje para empezar a compartir',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/publicar');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF854937),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Publicar Viaje'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarViajes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: viajesCreados.length,
        itemBuilder: (context, index) {
          final viaje = viajesCreados[index];
          return _buildViajeCard(viaje, esCreador: viaje.esCreador ?? true);
        },
      ),
    );
  }

  Widget _buildViajesUnidos() {
    if (viajesUnidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No te has unido a ningún viaje',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Busca viajes disponibles en el mapa para unirte',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/mapa');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF854937),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Buscar Viajes'),
            ),

          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarViajes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: viajesUnidos.length,
        itemBuilder: (context, index) {
          final viaje = viajesUnidos[index];
          return _buildViajeCard(viaje, esCreador: viaje.esCreador ?? false);
        },
      ),
    );
  }

  Widget _buildViajeCard(Viaje viaje, {required bool esCreador}) {
    // Usar la propiedad del modelo si está disponible, sino usar el parámetro
    final esCreadorReal = viaje.esCreador ?? esCreador;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFEDCAB6), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navegar a la pantalla de detalle correspondiente
          if (esCreadorReal) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetalleViajeConductorScreen(viaje: viaje),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetalleViajePasajeroScreen(viaje: viaje),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con estado y precio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: esCreadorReal ? const Color(0xFF854937) : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        esCreadorReal ? 'Mi Viaje' : 'Unido',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Mostrar estado solo para el conductor
                    if (esCreadorReal) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getEstadoColor(viaje.estado),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getEstadoTexto(viaje.estado),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '\$${viaje.precio.toInt()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF854937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Mostrar información del conductor si es un viaje al que se unió
            if (!esCreadorReal && viaje.conductor != null) ...[
              Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF854937), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Conductor: ${viaje.conductor!.nombre}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF854937),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            // Origen y destino
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    viaje.origen.nombre,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    viaje.destino.nombre,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Fecha y hora
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Text(
                  viaje.fechaIdaFormateada,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Text(
                  viaje.horaIda,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            
            // Vehículo (si disponible)
            if (viaje.vehiculo != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.directions_car, color: Color(0xFF854937), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${viaje.vehiculo!.modelo} - ${viaje.vehiculo!.patente}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Pasajeros y botones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${viaje.pasajeros.length}/${viaje.maxPasajeros} pasajeros',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Botón de pago solo cuando el viaje está completado
                    if (viaje.estado.toLowerCase() == 'completado') ...[
                      IconButton(
                        icon: const Icon(Icons.payment, size: 20, color: Colors.green),
                        tooltip: 'Pagar viaje',
                        onPressed: () {
                          _procesarPago(viaje);
                        },
                      ),
                    ],
                    // Botones de editar y borrar solo para el creador
                    if (esCreadorReal) ...[
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          // TODO: Implementar edición
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () {
                          _mostrarDialogoCancelar(viaje);
                        },
                      ),
                    ],
                    // Botón de abandonar viaje solo para los pasajeros
                    if (!esCreadorReal) ...[
                      IconButton(
                        icon: const Icon(Icons.exit_to_app, size: 20, color: Colors.orange),
                        tooltip: 'Abandonar viaje',
                        onPressed: () {
                          _mostrarDialogoAbandonar(viaje);
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

Future<void> _mostrarDialogoCancelar(Viaje viaje) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Cancelar Viaje'),
        content: const Text(
          '¿Estás seguro de que quieres cancelar este viaje? Esta acción no se puede deshacer.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sí, cancelar'),
          ),
        ],
      );
    },
  );

  if (confirmado == true) {
    try {
      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Eliminando viaje...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );
      }

      // Llamar al servicio para eliminar el viaje
      final resultado = await ViajeService.eliminarViaje(viaje.id);
      
      // Ocultar el snackbar de carga
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (resultado['success']) {
        // Recargar la lista de viajes
        await _cargarViajes();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['message']),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['message']),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Ocultar el snackbar de carga en caso de error
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar viaje: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

// Función para procesar el pago de un viaje
  Future<void> _procesarPago(Viaje viaje) async {
    try {
      // Mostrar diálogo de confirmación
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Procesar Pago'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Viaje: ${viaje.origen.nombre} → ${viaje.destino.nombre}'),
                const SizedBox(height: 8),
                Text('Precio: \$${viaje.precio.toInt()}'),
                const SizedBox(height: 8),
                Text('Fecha: ${viaje.fechaIda.day}/${viaje.fechaIda.month}/${viaje.fechaIda.year}'),
                const SizedBox(height: 16),
                const Text('¿Confirmas el pago de este viaje?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF854937),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Pagar'),
              ),
            ],
          );
        },
      );

      if (confirmado == true) {
        // Mostrar indicador de carga
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Procesando pago...'),
                ],
              ),
              backgroundColor: Color(0xFF854937),
            ),
          );
        }

        // Llamar al servicio de pago
        final respuesta = await PagoService.crearPago(
          viajeId: viaje.id,
          montoTotal: viaje.precio,
          descripcion: 'Pago viaje: ${viaje.origen.nombre} → ${viaje.destino.nombre} del ${viaje.fechaIda.day}/${viaje.fechaIda.month}/${viaje.fechaIda.year}',
        );

        if (mounted) {
          // Ocultar el snackbar de carga
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          if (respuesta['success'] == true) {
            final urlPago = respuesta['data']?['init_point'];
            
            if (urlPago != null) {
              // Mostrar diálogo con opciones de pago
              final opcion = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Pago Creado'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Se ha creado el pago exitosamente.'),
                        const SizedBox(height: 8),
                        const Text('¿Qué deseas hacer?'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop('later'),
                        child: const Text('Más tarde'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop('copy'),
                        child: const Text('Copiar URL'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop('open'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Abrir MercadoPago'),
                      ),
                    ],
                  );
                },
              );

              if (opcion == 'copy') {
                // Copiar URL al portapapeles
                await Clipboard.setData(ClipboardData(text: urlPago));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('URL copiada al portapapeles'),
                        const SizedBox(height: 4),
                        Text(urlPago, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 5),
                  ),
                );
              } else if (opcion == 'open') {
                // Abrir la URL de pago en el navegador
                final Uri url = Uri.parse(urlPago);
                
                print('🔗 Intentando abrir URL: $urlPago');
                print('🔗 URI parseada: $url');
                
                try {
                  // Verificar si se puede abrir la URL
                  final canLaunch = await canLaunchUrl(url);
                  print('🔗 ¿Se puede abrir la URL?: $canLaunch');
                  
                  if (canLaunch) {
                    final launched = await launchUrl(
                      url, 
                      mode: LaunchMode.externalApplication,
                      webOnlyWindowName: '_blank',
                    );
                    print('🔗 ¿Se lanzó exitosamente?: $launched');
                    
                    if (!launched) {
                      throw Exception('launchUrl retornó false');
                    }
                  } else {
                    // Intentar con modo interno si el externo falla
                    print('🔗 Intentando con modo interno...');
                    final launched = await launchUrl(url, mode: LaunchMode.inAppWebView);
                    
                    if (!launched) {
                      throw Exception('No se pudo abrir en ningún modo');
                    }
                  }
                } catch (e) {
                  print('❌ Error al abrir URL: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('No se pudo abrir el enlace de pago automáticamente'),
                          const SizedBox(height: 8),
                          Text('URL: $urlPago', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          const Text('Copia esta URL en tu navegador para completar el pago', 
                                   style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 10),
                      action: SnackBarAction(
                        label: 'Copiar URL',
                        textColor: Colors.white,
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: urlPago));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('URL copiada al portapapeles'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error: No se recibió URL de pago'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al crear el pago: ${respuesta['message'] ?? 'Error desconocido'}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar el pago: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Función para mostrar diálogo de abandonar viaje (para pasajeros)
  Future<void> _mostrarDialogoAbandonar(Viaje viaje) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Abandonar Viaje'),
          content: const Text(
            '¿Estás seguro de que quieres abandonar este viaje? Ya no serás parte de este viaje.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Sí, abandonar'),
            ),
          ],
        );
      },
    );

    if (confirmado == true) {
      try {
        // Mostrar indicador de carga
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Abandonando viaje...'),
                ],
              ),
              duration: Duration(seconds: 10),
            ),
          );
        }

        // Llamar al servicio para abandonar el viaje
        final resultado = await ViajeService.abandonarViaje(viaje.id);
        
        // Ocultar el snackbar de carga
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        if (resultado['success']) {
          // Recargar la lista de viajes
          await _cargarViajes();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(resultado['message'] ?? 'Has abandonado el viaje exitosamente'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(resultado['message'] ?? 'Error al abandonar el viaje'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e) {
        // Ocultar el snackbar de carga en caso de error
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al abandonar viaje: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  // Métodos auxiliares para estados
  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'confirmado':
        return Colors.blue;
      case 'en_curso':
        return Colors.green;
      case 'completado':
        return const Color(0xFF4CAF50);
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getEstadoTexto(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return 'Pendiente';
      case 'confirmado':
        return 'Confirmado';
      case 'en_curso':
        return 'En Curso';
      case 'completado':
        return 'Completado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado;
    }
  }
}
