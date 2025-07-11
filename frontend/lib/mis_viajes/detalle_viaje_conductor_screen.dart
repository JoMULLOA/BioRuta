import 'package:flutter/material.dart';
import '../models/viaje_model.dart';
import '../services/viaje_service.dart';
import '../services/ruta_service.dart';

class DetalleViajeConductorScreen extends StatefulWidget {
  final Viaje viaje;

  const DetalleViajeConductorScreen({
    super.key,
    required this.viaje,
  });

  @override
  State<DetalleViajeConductorScreen> createState() => _DetalleViajeConductorScreenState();
}

class _DetalleViajeConductorScreenState extends State<DetalleViajeConductorScreen> {
  late Viaje viaje;
  bool cargando = false;
  bool mostrarRutaRestante = false;

  @override
  void initState() {
    super.initState();
    viaje = widget.viaje;
    
    // Verificar si ya hay una ruta activa para este viaje
    mostrarRutaRestante = RutaService.instance.tieneRutaActiva(viaje.id);
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'activo':
        return Colors.green;
      case 'en_curso':
        return Colors.blue;
      case 'completado':
        return Colors.grey;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getEstadoTexto(String estado) {
    switch (estado) {
      case 'activo':
        return 'Activo';
      case 'en_curso':
        return 'En Curso';
      case 'completado':
        return 'Completado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return 'Desconocido';
    }
  }

  Future<void> _cambiarEstadoViaje(String nuevoEstado) async {
    String mensaje = '';
    switch (nuevoEstado) {
      case 'en_curso':
        mensaje = '¿Quieres iniciar este viaje?';
        break;
      case 'completado':
        mensaje = '¿Confirmas que el viaje ha sido completado?';
        break;
      case 'cancelado':
        mensaje = '¿Estás seguro de que quieres cancelar este viaje?';
        break;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cambiar Estado del Viaje'),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: nuevoEstado == 'cancelado' ? Colors.red : const Color(0xFF854937),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmado == true) {
      setState(() {
        cargando = true;
      });

      try {
        final resultado = await ViajeService.cambiarEstadoViaje(viaje.id, nuevoEstado);

        if (mounted) {
          if (resultado['success'] == true) {
            setState(() {
              viaje = viaje.copyWith(estado: nuevoEstado);
              cargando = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(resultado['message']),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            setState(() {
              cargando = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(resultado['message']),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            cargando = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmarPasajero(String usuarioRut, String nombrePasajero) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Pasajero'),
          content: Text('¿Confirmas a $nombrePasajero como pasajero de este viaje?'),
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
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmado == true) {
      try {
        final resultado = await ViajeService.confirmarPasajero(viaje.id, usuarioRut);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['message']),
              backgroundColor: resultado['success'] == true ? Colors.green : Colors.red,
            ),
          );

          if (resultado['success'] == true) {
            // Recargar datos del viaje o actualizar localmente
            // Por simplicidad, mostraremos el mensaje de éxito
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _toggleRutaRestante() {
    setState(() {
      mostrarRutaRestante = !mostrarRutaRestante;
    });
    
    if (mostrarRutaRestante) {
      // Activar ruta restante en el servicio global
      RutaService.instance.activarRutaRestante(
        viajeId: viaje.id,
        destinoNombre: viaje.destino.nombre,
        destinoLat: viaje.destino.latitud,
        destinoLng: viaje.destino.longitud,
        esConductor: true,
      );
    } else {
      // Desactivar ruta
      RutaService.instance.desactivarRuta();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: const Text('Detalle del Viaje'),
        backgroundColor: const Color(0xFF854937),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF854937)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado del viaje
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getEstadoColor(viaje.estado),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Estado: ${_getEstadoTexto(viaje.estado)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF854937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Información del viaje
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Información del Viaje',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF854937),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          _buildInfoRow(Icons.location_on, 'Origen', viaje.origen.nombre, Colors.green),
                          _buildInfoRow(Icons.flag, 'Destino', viaje.destino.nombre, Colors.red),
                          _buildInfoRow(Icons.calendar_today, 'Fecha', 
                            '${viaje.fechaIda.day}/${viaje.fechaIda.month}/${viaje.fechaIda.year}', Colors.blue),
                          _buildInfoRow(Icons.access_time, 'Hora', viaje.horaIda, Colors.blue),
                          _buildInfoRow(Icons.attach_money, 'Precio', '\$${viaje.precio.toInt()}', Colors.orange),
                          
                          if (viaje.vehiculo != null) ...[
                            _buildInfoRow(Icons.directions_car, 'Vehículo', 
                              '${viaje.vehiculo!.modelo} - ${viaje.vehiculo!.patente}', const Color(0xFF854937)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pasajeros
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Pasajeros',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF854937),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${viaje.pasajeros.length}/${viaje.maxPasajeros}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          if (viaje.pasajeros.isEmpty)
                            const Text(
                              'No hay pasajeros aún',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            ...viaje.pasajeros.map((pasajero) => _buildPasajeroCard(pasajero)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botones de acción
                  _buildBotonesAccion(),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
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

  Widget _buildPasajeroCard(PasajeroViaje pasajero) {
    final usuario = pasajero.usuario;
    final nombre = usuario?['nombre'] ?? 'Usuario ${pasajero.usuarioRut}';
    
    Color estadoColor;
    String estadoTexto;
    
    switch (pasajero.estado) {
      case 'confirmado':
        estadoColor = Colors.green;
        estadoTexto = 'Confirmado';
        break;
      case 'pendiente':
        estadoColor = Colors.orange;
        estadoTexto = 'Pendiente';
        break;
      case 'rechazado':
        estadoColor = Colors.red;
        estadoTexto = 'Rechazado';
        break;
      default:
        estadoColor = Colors.grey;
        estadoTexto = 'Desconocido';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: estadoColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${pasajero.pasajerosSolicitados} pasajero(s) - $estadoTexto',
                  style: TextStyle(
                    fontSize: 12,
                    color: estadoColor,
                  ),
                ),
                if (pasajero.mensaje != null && pasajero.mensaje!.isNotEmpty)
                  Text(
                    pasajero.mensaje!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          if (pasajero.estado == 'pendiente')
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () => _confirmarPasajero(pasajero.usuarioRut, nombre),
              tooltip: 'Confirmar pasajero',
            ),
        ],
      ),
    );
  }

  Widget _buildBotonesAccion() {
    final estado = viaje.estado;
    
    return Column(
      children: [
        // Checkbox para mostrar ruta restante
        CheckboxListTile(
          title: const Text(
            'Activar seguimiento de ruta restante',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: const Text(
            'Activa esta opción para ver el camino restante desde tu ubicación actual',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          value: mostrarRutaRestante,
          onChanged: (bool? value) => _toggleRutaRestante(),
          activeColor: const Color(0xFF854937),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        
        const SizedBox(height: 16),
        
        if (estado == 'activo') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _cambiarEstadoViaje('en_curso'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar Viaje'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        if (estado == 'en_curso') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _cambiarEstadoViaje('completado'),
              icon: const Icon(Icons.flag),
              label: const Text('Completar Viaje'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF854937),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (estado == 'activo' || estado == 'en_curso') ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _cambiarEstadoViaje('cancelado'),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancelar Viaje'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],

        if (estado == 'completado') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Viaje Completado',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],

        if (estado == 'cancelado') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Viaje Cancelado',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

extension ViajeExtension on Viaje {
  Viaje copyWith({
    String? id,
    String? usuarioRut,
    String? vehiculoPatente,
    UbicacionViaje? origen,
    UbicacionViaje? destino,
    DateTime? fechaIda,
    String? horaIda,
    DateTime? fechaVuelta,
    String? horaVuelta,
    bool? viajeIdaVuelta,
    int? maxPasajeros,
    bool? soloMujeres,
    String? flexibilidadSalida,
    double? precio,
    int? plazasDisponibles,
    String? comentarios,
    List<PasajeroViaje>? pasajeros,
    String? estado,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    Conductor? conductor,
    VehiculoViaje? vehiculo,
    double? distanciaOrigen,
    double? distanciaDestino,
    bool? esCreador,
    bool? esUnido,
  }) {
    return Viaje(
      id: id ?? this.id,
      usuarioRut: usuarioRut ?? this.usuarioRut,
      vehiculoPatente: vehiculoPatente ?? this.vehiculoPatente,
      origen: origen ?? this.origen,
      destino: destino ?? this.destino,
      fechaIda: fechaIda ?? this.fechaIda,
      horaIda: horaIda ?? this.horaIda,
      fechaVuelta: fechaVuelta ?? this.fechaVuelta,
      horaVuelta: horaVuelta ?? this.horaVuelta,
      viajeIdaVuelta: viajeIdaVuelta ?? this.viajeIdaVuelta,
      maxPasajeros: maxPasajeros ?? this.maxPasajeros,
      soloMujeres: soloMujeres ?? this.soloMujeres,
      flexibilidadSalida: flexibilidadSalida ?? this.flexibilidadSalida,
      precio: precio ?? this.precio,
      plazasDisponibles: plazasDisponibles ?? this.plazasDisponibles,
      comentarios: comentarios ?? this.comentarios,
      pasajeros: pasajeros ?? this.pasajeros,
      estado: estado ?? this.estado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      conductor: conductor ?? this.conductor,
      vehiculo: vehiculo ?? this.vehiculo,
      distanciaOrigen: distanciaOrigen ?? this.distanciaOrigen,
      distanciaDestino: distanciaDestino ?? this.distanciaDestino,
      esCreador: esCreador ?? this.esCreador,
      esUnido: esUnido ?? this.esUnido,
    );
  }
}
