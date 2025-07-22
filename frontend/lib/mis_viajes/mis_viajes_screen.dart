import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/viaje_service.dart';
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
  List<Viaje> viajesCreadosOriginales = [];
  List<Viaje> viajesUnidosOriginales = [];
  bool cargando = true;
  bool _isBuilding = false;  // Flag para prevenir builds múltiples
  int _selectedIndex = 0; // Mis viajes ahora está en índice 0
  int numeroSolicitudesPendientes = 0;
  late TabController _tabController;
  
  // Variable para rastrear el listener
  late VoidCallback _tabListener;
  
  // Variable para el filtro de período
  String _periodoSeleccionado = 'Todos';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1); // Iniciar en "Viajes unidos"
    
    // Crear y asignar el listener
    _tabListener = () {
      if (mounted && !_tabController.indexIsChanging && !_isBuilding) {
        _isBuilding = true;
        setState(() {}); // Actualizar el FAB y el contador cuando cambie de pestaña
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _isBuilding = false;
          }
        });
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
        viajesCreadosOriginales = viajes.where((v) => v.esCreador == true).toList();
        viajesUnidosOriginales = viajes.where((v) => v.esUnido == true).toList();
        
        // Aplicar filtros
        _aplicarFiltrosPeriodo();
        
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

// Método para aplicar filtros por período
void _aplicarFiltrosPeriodo() {
  final ahora = DateTime.now();
  DateTime fechaInicio;
  
  switch (_periodoSeleccionado) {
    case 'Hoy':
      fechaInicio = DateTime(ahora.year, ahora.month, ahora.day);
      break;
    case 'Esta semana':
      final diasHastaLunes = (ahora.weekday - 1) % 7;
      fechaInicio = DateTime(ahora.year, ahora.month, ahora.day - diasHastaLunes);
      break;
    case 'Este mes':
      fechaInicio = DateTime(ahora.year, ahora.month, 1);
      break;
    default: // 'Todos'
      viajesCreados = List.from(viajesCreadosOriginales);
      viajesUnidos = List.from(viajesUnidosOriginales);
      return;
  }
  
  // Filtrar viajes creados
  viajesCreados = viajesCreadosOriginales.where((viaje) {
    return viaje.fechaIda.isAfter(fechaInicio.subtract(const Duration(days: 1)));
  }).toList();
  
  // Filtrar viajes unidos
  viajesUnidos = viajesUnidosOriginales.where((viaje) {
    return viaje.fechaIda.isAfter(fechaInicio.subtract(const Duration(days: 1)));
  }).toList();
}

// Método para cambiar el período seleccionado
void _cambiarPeriodo(String nuevoPeriodo) {
  if (_periodoSeleccionado == nuevoPeriodo || _isBuilding) return;
  
  setState(() {
    _periodoSeleccionado = nuevoPeriodo;
    _aplicarFiltrosPeriodo();
  });
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
      onContadorCambiado: () {
        // Actualizar el contador cuando haya cambios automáticos
        if (mounted) {
          _cargarSolicitudesPendientes();
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
        actions: [
          // Selector de período
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _periodoSeleccionado,
              dropdownColor: const Color(0xFF8D4F3A),
              underline: Container(),
              icon: const Icon(Icons.filter_list, color: Colors.white),
              items: const [
                DropdownMenuItem(
                  value: 'Todos',
                  child: Text('Todos', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'Hoy',
                  child: Text('Hoy', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'Esta semana',
                  child: Text('Esta semana', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'Este mes',
                  child: Text('Este mes', style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _cambiarPeriodo(newValue);
                }
              },
            ),
          ),
        ],
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
          : Column(
              children: [
                // Indicador del filtro activo (solo si no es "Todos")
                if (_periodoSeleccionado != 'Todos')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFFEDCAB6),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, size: 16, color: Color(0xFF854937)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final count = _tabController.index == 0 ? viajesCreados.length : viajesUnidos.length;
                              final tabName = _tabController.index == 0 ? 'publicaciones' : 'unidos';
                              return Text(
                                'Mostrando $_periodoSeleccionado: $count $tabName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF854937),
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _cambiarPeriodo('Todos'),
                          child: const Text(
                            'Ver todos',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF854937),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // TabBarView
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildViajesCreados(),
                      _buildViajesUnidos(),
                    ],
                  ),
                ),
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
      final String mensaje = _periodoSeleccionado == 'Todos' 
          ? 'No has publicado ningún viaje'
          : 'No tienes viajes publicados $_periodoSeleccionado'.toLowerCase();
          
      final String submensaje = _periodoSeleccionado == 'Todos'
          ? 'Publica tu primer viaje para empezar a compartir'
          : 'Cambia el filtro de período o publica un nuevo viaje';
          
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
              mensaje,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              submensaje,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_periodoSeleccionado != 'Todos') ...[
              ElevatedButton(
                onPressed: () => _cambiarPeriodo('Todos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Ver Todos los Viajes'),
              ),
              const SizedBox(height: 12),
            ],
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
      final String mensaje = _periodoSeleccionado == 'Todos' 
          ? 'No te has unido a ningún viaje'
          : 'No tienes viajes unidos $_periodoSeleccionado'.toLowerCase();
          
      final String submensaje = _periodoSeleccionado == 'Todos'
          ? 'Busca viajes disponibles en el mapa para unirte'
          : 'Cambia el filtro de período o busca nuevos viajes';
          
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
              mensaje,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              submensaje,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_periodoSeleccionado != 'Todos') ...[
              ElevatedButton(
                onPressed: () => _cambiarPeriodo('Todos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Ver Todos los Viajes'),
              ),
              const SizedBox(height: 12),
            ],
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
