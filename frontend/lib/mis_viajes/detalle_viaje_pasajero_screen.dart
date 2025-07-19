import 'package:flutter/material.dart';
import '../models/viaje_model.dart';
import '../services/ruta_service.dart';

class DetalleViajePasajeroScreen extends StatefulWidget {
  final Viaje viaje;

  const DetalleViajePasajeroScreen({
    super.key,
    required this.viaje,
  });

  @override
  State<DetalleViajePasajeroScreen> createState() => _DetalleViajePasajeroScreenState();
}

class _DetalleViajePasajeroScreenState extends State<DetalleViajePasajeroScreen> {
  late Viaje viaje;
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
        return 'Esperando inicio';
      case 'en_curso':
        return 'En curso';
      case 'completado':
        return 'Completado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return 'Desconocido';
    }
  }

  String _getEstadoPasajeroTexto(String estado) {
    switch (estado) {
      case 'confirmado':
        return 'Confirmado';
      case 'pendiente':
        return 'Pendiente de confirmación';
      case 'rechazado':
        return 'Rechazado';
      default:
        return 'Desconocido';
    }
  }

  Color _getEstadoPasajeroColor(String estado) {
    switch (estado) {
      case 'confirmado':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'rechazado':
        return Colors.red;
      default:
        return Colors.grey;
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
        esConductor: false,
      );
    } else {
      // Desactivar ruta
      RutaService.instance.desactivarRuta();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Encontrar el estado del usuario actual como pasajero
    // Por simplicidad, asumimos que es el primer pasajero, pero en una implementación real
    // deberías buscar por el RUT del usuario actual
    final miEstadoPasajero = viaje.pasajeros.isNotEmpty ? viaje.pasajeros.first.estado : 'pendiente';

    return Scaffold(
      backgroundColor: const Color(0xFFF2EEED),
      appBar: AppBar(
        title: const Text('Detalle del Viaje'),
        backgroundColor: const Color(0xFF854937),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
                child: Column(
                  children: [
                    Row(
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
                          'Viaje: ${_getEstadoTexto(viaje.estado)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF854937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getEstadoPasajeroColor(miEstadoPasajero),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Tu estado: ${_getEstadoPasajeroTexto(miEstadoPasajero)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF854937),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Información del conductor
            if (viaje.conductor != null)
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
                        'Conductor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF854937),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF854937),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  viaje.conductor!.nombre,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  viaje.conductor!.email,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.message, color: Color(0xFF854937)),
                            onPressed: () {
                              // TODO: Implementar chat o contacto con conductor
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Función de chat en desarrollo'),
                                ),
                              );
                            },
                            tooltip: 'Contactar conductor',
                          ),
                        ],
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
                    _buildInfoRow(Icons.people, 'Pasajeros', 
                      '${viaje.pasajeros.length}/${viaje.maxPasajeros}', Colors.purple),
                    
                    if (viaje.vehiculo != null) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Vehículo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF854937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.directions_car, 'Modelo', viaje.vehiculo!.modelo, const Color(0xFF854937)),
                      _buildInfoRow(Icons.confirmation_number, 'Patente', viaje.vehiculo!.patente, const Color(0xFF854937)),
                      _buildInfoRow(Icons.palette, 'Color', viaje.vehiculo!.color, const Color(0xFF854937)),
                      _buildInfoRow(Icons.airline_seat_recline_normal, 'Asientos', viaje.vehiculo!.nroAsientos.toString(), const Color(0xFF854937)),
                    ],

                    if (viaje.comentarios != null && viaje.comentarios!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Comentarios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF854937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        viaje.comentarios!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Otros pasajeros
            if (viaje.pasajeros.length > 1)
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
                        'Otros Pasajeros',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF854937),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      ...viaje.pasajeros.skip(1).map((pasajero) => _buildOtroPasajeroCard(pasajero)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

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
                'Activa esta opción para seguir el progreso del viaje en tiempo real',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              value: mostrarRutaRestante,
              onChanged: (bool? value) => _toggleRutaRestante(),
              activeColor: const Color(0xFF854937),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 16),

            // Información según el estado
            _buildInformacionEstado(),
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

  Widget _buildOtroPasajeroCard(PasajeroViaje pasajero) {
    final usuario = pasajero.usuario;
    final nombre = usuario?['nombre'] ?? 'Pasajero ${pasajero.usuarioRut}';
    
    Color estadoColor;
    switch (pasajero.estado) {
      case 'confirmado':
        estadoColor = Colors.green;
        break;
      case 'pendiente':
        estadoColor = Colors.orange;
        break;
      case 'rechazado':
        estadoColor = Colors.red;
        break;
      default:
        estadoColor = Colors.grey;
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
                  '${pasajero.pasajerosSolicitados} pasajero(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformacionEstado() {
    final miEstadoPasajero = viaje.pasajeros.isNotEmpty ? viaje.pasajeros.first.estado : 'pendiente';
    
    Widget contenido;
    Color backgroundColor;
    IconData icon;
    
    if (viaje.estado == 'cancelado') {
      backgroundColor = Colors.red[100]!;
      icon = Icons.cancel;
      contenido = const Column(
        children: [
          Text(
            'Viaje Cancelado',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Este viaje ha sido cancelado por el conductor',
            style: TextStyle(
              color: Colors.red,
              fontSize: 14,
            ),
          ),
        ],
      );
    } else if (miEstadoPasajero == 'pendiente') {
      backgroundColor = Colors.orange[100]!;
      icon = Icons.hourglass_empty;
      contenido = const Column(
        children: [
          Text(
            'Esperando Confirmación',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'El conductor aún no ha confirmado tu solicitud',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 14,
            ),
          ),
        ],
      );
    } else if (miEstadoPasajero == 'confirmado' && viaje.estado == 'activo') {
      backgroundColor = Colors.green[100]!;
      icon = Icons.check_circle;
      contenido = const Column(
        children: [
          Text(
            'Confirmado - Esperando Inicio',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Estás confirmado para este viaje. Espera que el conductor lo inicie.',
            style: TextStyle(
              color: Colors.green,
              fontSize: 14,
            ),
          ),
        ],
      );
    } else if (viaje.estado == 'en_curso') {
      backgroundColor = Colors.blue[100]!;
      icon = Icons.directions_car;
      contenido = const Column(
        children: [
          Text(
            'Viaje en Curso',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '¡Disfruta tu viaje!',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 14,
            ),
          ),
        ],
      );
    } else if (viaje.estado == 'completado') {
      backgroundColor = Colors.green[100]!;
      icon = Icons.flag;
      contenido = const Column(
        children: [
          Text(
            'Viaje Completado',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '¡Esperamos que hayas tenido un buen viaje!',
            style: TextStyle(
              color: Colors.green,
              fontSize: 14,
            ),
          ),
        ],
      );
    } else {
      backgroundColor = Colors.grey[100]!;
      icon = Icons.info;
      contenido = const Text(
        'Estado del viaje actualizado',
        style: TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: backgroundColor == Colors.red[100] ? Colors.red :
                     backgroundColor == Colors.orange[100] ? Colors.orange :
                     backgroundColor == Colors.green[100] ? Colors.green :
                     backgroundColor == Colors.blue[100] ? Colors.blue : Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: contenido),
        ],
      ),
    );
  }
}
