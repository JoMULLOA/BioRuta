import 'package:flutter/material.dart';
import '../models/viaje_model.dart';
import '../services/ruta_service.dart';
import '../services/viaje_service.dart';
import '../utils/map_launcher.dart';
import '../chat/chat_grupal.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/token_manager.dart';
import '../config/confGlobal.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  
  // Variable para almacenar la calificación del conductor
  double _calificacionConductor = 0;
  bool _yaSeVerificoCalificacion = false;

  @override
  void initState() {
    super.initState();
    viaje = widget.viaje;
    
    // Verificar si ya hay una ruta activa para este viaje
    mostrarRutaRestante = RutaService.instance.tieneRutaActiva(viaje.id);
    
    // Verificar si ya se calificó al conductor para este viaje
    _verificarSiYaCalificoConductor();
  }

  Future<void> _verificarSiYaCalificoConductor() async {
    if (viaje.estado == 'completado' && !_yaSeVerificoCalificacion) {
      _yaSeVerificoCalificacion = true;
      
      try {
        final headers = await TokenManager.getAuthHeaders();
        if (headers == null) return;

        // Verificar si ya existe una calificación de este pasajero hacia este conductor para este viaje
        // Esto se puede hacer consultando las transacciones o creando un endpoint específico
        // Por ahora, usaremos SharedPreferences como solución temporal
        final prefs = await SharedPreferences.getInstance();
        final keyCalificacion = 'calificacion_conductor_${viaje.id}_${viaje.conductor?.rut}';
        final yaCalificado = prefs.getBool(keyCalificacion) ?? false;
        
        if (!yaCalificado) {
          // Solo mostrar el modal si no se ha calificado antes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mostrarModalCalificacion();
            }
          });
        }
      } catch (e) {
        print('Error verificando calificación previa: $e');
      }
    }
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

  Future<void> _guardarCalificacion(double calificacion) async {
    try {
      final headers = await TokenManager.getAuthHeaders();
      if (headers == null) {
        throw Exception('No se pudo obtener el token de autenticación');
      }

      headers['Content-Type'] = 'application/json';

      final response = await http.post(
        Uri.parse('${confGlobal.baseUrl}/user/calificar'),
        headers: headers,
        body: json.encode({
          'rutUsuarioCalificado': viaje.conductor!.rut,
          'calificacion': calificacion,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Guardar en SharedPreferences que ya se calificó al conductor ANTES del setState
          final prefs = await SharedPreferences.getInstance();
          final keyCalificacion = 'calificacion_conductor_${viaje.id}_${viaje.conductor?.rut}';
          await prefs.setBool(keyCalificacion, true);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Calificación guardada exitosamente'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          throw Exception(data['message'] ?? 'Error al guardar la calificación');
        }
      } else {
        throw Exception('Error del servidor al guardar la calificación');
      }
    } catch (e) {
      print('Error al calificar conductor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar la calificación: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _abandonarViaje() async {
    // Mostrar diálogo de confirmación
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¿Abandonar viaje?'),
          content: const Text(
            'Si abandonas este viaje, se procesará automáticamente la devolución del dinero pagado según el método de pago utilizado.\n\n'
            '¿Estás seguro de que deseas continuar?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Abandonar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Procesando abandono del viaje...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final resultado = await ViajeService.abandonarViaje(viaje.id);

      if (mounted) {
        if (resultado['success'] == true) {
          // Mostrar mensaje de éxito con información de devolución
          String mensaje = resultado['message'] ?? 'Has abandonado el viaje exitosamente';
          
          if (resultado['devolucion'] != null && resultado['devolucion']['success'] == true) {
            final devolucion = resultado['devolucion'];
            if (devolucion['tipo'] == 'efectivo') {
              mensaje += '\n\nSe han eliminado las transacciones pendientes en efectivo.';
            } else {
              mensaje += '\n\nSe ha procesado la devolución de \$${devolucion['monto']} a tu saldo.';
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensaje),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );

          // Regresar a la pantalla anterior
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['message'] ?? 'Error al abandonar el viaje'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _mostrarModalCalificacion() {
    // Color palette from perfil.dart
    final Color primario = Color(0xFF6B3B2D);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Califica a tu conductor',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B3B2D),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (viaje.conductor != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primario.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: primario,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              viaje.conductor!.nombre,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: primario,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    '¿Cómo fue tu experiencia con el conductor?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  // Sistema de estrellas igual al del conductor
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final estrella = index + 1;
                      final estaSeleccionada = estrella <= _calificacionConductor;
                      
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            _calificacionConductor = estrella.toDouble();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            estaSeleccionada ? Icons.star : Icons.star_border,
                            color: estaSeleccionada ? const Color(0xFFFFD700) : Colors.grey[400],
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (_calificacionConductor > 0)
                    Text(
                      'Calificación: ${_calificacionConductor.toInt()}/5 estrellas',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF854937),
                      ),
                    ),
                ],
              ),
              actions: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Omitir',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _calificacionConductor > 0
                          ? () async {
                              Navigator.of(context).pop();
                              await _guardarCalificacion(_calificacionConductor);
                            }
                          : null,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primario,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Color palette from perfil.dart
    final Color fondo = Color(0xFFF8F2EF);
    final Color primario = Color(0xFF6B3B2D);
    final Color secundario = Color(0xFF8D4F3A);
    
    // Encontrar el estado del usuario actual como pasajero
    // Por simplicidad, asumimos que es el primer pasajero, pero en una implementación real
    // deberías buscar por el RUT del usuario actual
    final miEstadoPasajero = viaje.pasajeros.isNotEmpty ? viaje.pasajeros.first.estado : 'pendiente';

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Detalle del Viaje'),
        backgroundColor: secundario,
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primario,
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: primario,
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
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primario.withOpacity(0.05),
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.person_pin_circle,
                              color: Color(0xFF6B3B2D),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Tu Conductor',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B3B2D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: primario,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primario.withOpacity(0.3),
                                    spreadRadius: 2,
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    viaje.conductor!.nombre,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF070505),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.email,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          viaje.conductor!.email,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: primario.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.message,
                                  color: primario,
                                  size: 20,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatGrupalScreen(
                                        idViaje: viaje.id.toString(),
                                        nombreViaje: null,
                                      ),
                                    ),
                                  );
                                },
                                tooltip: 'Contactar conductor',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Información del viaje
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.route,
                          color: Color(0xFF6B3B2D),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Detalles del Viaje',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B3B2D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    _buildInfoRow(Icons.my_location, 'Origen', viaje.origen.nombre, primario),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.location_on, 'Destino', viaje.destino.nombre, primario),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.calendar_today, 'Fecha', 
                      '${viaje.fechaIda.day}/${viaje.fechaIda.month}/${viaje.fechaIda.year}', secundario),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.schedule, 'Hora de salida', viaje.horaIda, secundario),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.attach_money, 'Precio por persona', '\$${viaje.precio.toInt()}', Colors.green[700]!),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.people, 'Ocupación', 
                      '${viaje.pasajeros.length}/${viaje.maxPasajeros} pasajeros', primario),

                    if (viaje.comentarios != null && viaje.comentarios!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.comment,
                            color: Color(0xFF6B3B2D),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Comentarios del conductor',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B3B2D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          viaje.comentarios!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Información del vehículo (mejorada)
            if (viaje.vehiculo != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primario.withOpacity(0.05),
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primario.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.directions_car,
                                color: primario,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Vehículo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primario,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: secundario.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: secundario.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.car_rental,
                                color: secundario,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${viaje.vehiculo!.modelo} • ${viaje.vehiculo!.patente}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: primario,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Otros pasajeros
            if (viaje.pasajeros.length > 1)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.people,
                            color: Color(0xFF6B3B2D),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Compañeros de Viaje',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B3B2D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Mostrar todos los pasajeros excepto el usuario actual
                      ...viaje.pasajeros.map((pasajero) => _buildOtroPasajeroCard(pasajero)),
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
              activeColor: primario,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 16),

            // Botones de navegación
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
                        const Icon(
                          Icons.navigation,
                          color: Color(0xFF6B3B2D),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Navegación',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B3B2D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              MapLauncher.openRouteInGoogleMaps(
                                viaje.origen.latitud,
                                viaje.origen.longitud,
                                viaje.destino.latitud,
                                viaje.destino.longitud,
                              );
                            },
                            icon: const Icon(Icons.map, size: 18),
                            label: const Text('Google Maps'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              MapLauncher.openRouteInWaze(
                                viaje.destino.latitud,
                                viaje.destino.longitud,
                              );
                            },
                            icon: const Icon(Icons.navigation, size: 18),
                            label: const Text('Waze'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // Información según el estado
            _buildInformacionEstado(),
            
            const SizedBox(height: 24),

            // Botón para abandonar viaje (solo visible si está confirmado y viaje activo/en curso)
            if ((viaje.estado == 'activo' || viaje.estado == 'en_curso') &&
                viaje.pasajeros.isNotEmpty &&
                viaje.pasajeros.first.estado == 'confirmado')
              Container(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _abandonarViaje,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Abandonar Viaje'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF070505),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: estadoColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: estadoColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF070505),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        estadoTexto,
                        style: TextStyle(
                          fontSize: 12,
                          color: estadoColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pasajero.pasajerosSolicitados} pasajero(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
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
