import 'package:flutter/material.dart';
import '../services/viaje_service.dart';
import '../models/viaje_model.dart';
import '../navbar_widget.dart';

class MisViajesScreen extends StatefulWidget {
  const MisViajesScreen({super.key});

  @override
  State<MisViajesScreen> createState() => _MisViajesScreenState();
}

class _MisViajesScreenState extends State<MisViajesScreen> {
  List<Viaje> viajesCreados = [];
  List<Viaje> viajesUnidos = [];
  bool cargando = true;
  int _selectedIndex = 5; // Perfil section

  @override
  void initState() {
    super.initState();
    _cargarViajes();
  }

  Future<void> _cargarViajes() async {
    try {
      setState(() {
        cargando = true;
      });

      // Cargar viajes creados por el usuario y viajes a los que se ha unido
      final viajesData = await ViajeService.obtenerViajesUsuario();
      final List<Viaje> viajes = viajesData.map((v) => Viaje.fromJson(v)).toList();

      setState(() {
        // Separar viajes creados de viajes a los que se unió
        viajesCreados = viajes.where((v) => v.estado == 'activo').toList();
        viajesUnidos = viajes.where((v) => v.pasajeros.isNotEmpty).toList();
        cargando = false;
      });
    } catch (e) {
      setState(() {
        cargando = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar viajes: $e')),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: const Text('Mis Viajes'),
        backgroundColor: const Color(0xFF854937),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF854937)),
              ),
            )
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: const TabBar(
                      labelColor: Color(0xFF854937),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Color(0xFF854937),
                      tabs: [
                        Tab(text: 'Mis Publicaciones'),
                        Tab(text: 'Viajes Unidos'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildViajesCreados(),
                        _buildViajesUnidos(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: CustomNavbar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
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
          return _buildViajeCard(viajesCreados[index], esCreador: true);
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
              'Busca viajes en el mapa para encontrar compañeros de ruta',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/viajes');
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
          return _buildViajeCard(viajesUnidos[index], esCreador: false);
        },
      ),
    );
  }

  Widget _buildViajeCard(Viaje viaje, {required bool esCreador}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFEDCAB6), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con estado y precio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: esCreador ? const Color(0xFF854937) : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    esCreador ? 'Mi Viaje' : 'Unido',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                  '${viaje.fechaIda.day}/${viaje.fechaIda.month}/${viaje.fechaIda.year}',
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
            
            // Pasajeros
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
                if (esCreador)
                  Row(
                    children: [
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
                  ),
              ],
            ),
          ],
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
        // TODO: Implementar cancelación en el servicio
        // await ViajeService.cancelarViaje(viaje.id);
        await _cargarViajes(); // Recargar lista
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Viaje cancelado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cancelar viaje: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
