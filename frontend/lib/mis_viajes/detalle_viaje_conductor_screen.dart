import 'package:flutter/material.dart';
import '../models/viaje_model.dart';
import '../services/viaje_service.dart';
import '../services/ruta_service.dart';
import '../utils/map_launcher.dart';
import '../chat/chat_grupal.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/token_manager.dart';
import '../config/confGlobal.dart';

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

  // Mapa para almacenar las calificaciones de los pasajeros (usuarioRut -> calificación)
  final Map<String, double> _calificacionesPasajeros = {};

  @override
  void initState() {
    super.initState();
    viaje = widget.viaje;
    
    // Verificar si ya hay una ruta activa para este viaje
    mostrarRutaRestante = RutaService.instance.tieneRutaActiva(viaje.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Actualizar el estado del checkbox cada vez que la pantalla se vuelva visible
    setState(() {
      mostrarRutaRestante = RutaService.instance.tieneRutaActiva(viaje.id);
    });
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

  IconData _getEstadoIcon(String estado) {
    switch (estado) {
      case 'activo':
        return Icons.schedule;
      case 'en_curso':
        return Icons.directions_car;
      case 'completado':
        return Icons.check_circle;
      case 'cancelado':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Future<void> _cambiarEstadoViaje(String nuevoEstado) async {
    // Validación especial para iniciar viaje
    if (nuevoEstado == 'en_curso') {
      final pasajerosConfirmados = viaje.pasajeros.where((p) => p.estado == 'confirmado').toList();
      
      if (pasajerosConfirmados.isEmpty) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No se puede iniciar el viaje',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'No puedes iniciar el viaje sin pasajeros confirmados.\n\n'
                'Necesitas al menos un pasajero confirmado para comenzar el viaje.',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF854937),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Entendido'),
                ),
              ],
            );
          },
        );
        return; // Salir sin continuar con el cambio de estado
      }
    }

    String mensaje = '';
    switch (nuevoEstado) {
      case 'en_curso':
        final pasajerosConfirmados = viaje.pasajeros.where((p) => p.estado == 'confirmado').length;
        mensaje = '¿Quieres iniciar este viaje con $pasajerosConfirmados pasajero(s) confirmado(s)?';
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

            // Mostrar ventana con información de pasajeros solo cuando se completa el viaje
            if (nuevoEstado == 'completado') {
              print('🎯 DEBUG: Viaje completado, mostrando resumen de pasajeros');
              print('🎯 DEBUG: Pasajeros totales: ${viaje.pasajeros.length}');
              print('🎯 DEBUG: Pasajeros confirmados: ${viaje.pasajeros.where((p) => p.estado == 'confirmado').length}');
              
              // Usar Future.delayed para asegurar que el modal se muestre después del SnackBar
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _mostrarResumenPasajeros(nuevoEstado);
                }
              });
            }
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

  Future<void> _mostrarResumenPasajeros(String estadoViaje) async {
    // Filtrar solo pasajeros confirmados
    final pasajerosConfirmados = viaje.pasajeros.where((p) => p.estado == 'confirmado').toList();
    
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevenir cerrar tocando fuera del modal
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    _getEstadoIcon(estadoViaje),
                    color: _getEstadoColor(estadoViaje),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text('Viaje ${_getEstadoTexto(estadoViaje)}'),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Califica a tus pasajeros (${pasajerosConfirmados.length}):',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF854937),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (pasajerosConfirmados.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              'No hubo pasajeros confirmados en este viaje',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: pasajerosConfirmados.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final pasajero = pasajerosConfirmados[index];
                            return _buildResumenPasajeroConfirmado(pasajero, setModalState);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    // Mostrar progreso de calificaciones
                    Expanded(
                      child: Text(
                        'Calificados: ${_calificacionesPasajeros.entries.where((entry) => entry.value > 0).length}/${pasajerosConfirmados.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Verificar si hay calificaciones pendientes
                        final pasajerosSinCalificar = pasajerosConfirmados
                            .where((p) => (_calificacionesPasajeros[p.usuarioRut] ?? 0) == 0)
                            .toList();
                        
                        if (pasajerosSinCalificar.isNotEmpty) {
                          // Mostrar confirmación si hay pasajeros sin calificar
                          final continuar = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Calificaciones Pendientes'),
                                content: Text(
                                  '${pasajerosSinCalificar.length} pasajero(s) sin calificar.\n\n¿Deseas guardar las calificaciones actuales?'
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
                                    ),
                                    child: const Text('Guardar'),
                                  ),
                                ],
                              );
                            },
                          );
                          
                          if (continuar != true) return;
                        }
                        
                        // Guardar todas las calificaciones pendientes
                        await _guardarTodasLasCalificaciones();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF854937),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildResumenPasajeroConfirmado(PasajeroViaje pasajero, StateSetter setModalState) {
    final usuario = pasajero.usuario;
    final nombre = usuario?['nombre'] ?? 'Usuario ${pasajero.usuarioRut}';
    
    // Obtener la clasificación del usuario usando el mismo método que el perfil
    String clasificacionTexto = 'Sin clasificación';
    
    if (usuario?['clasificacion'] != null) {
      try {
        final clasificacionOriginal = double.parse(usuario!['clasificacion'].toString());
        // Por ahora usar la clasificación original, pero idealmente debería usar 
        // el mismo cálculo bayesiano que el perfil
        clasificacionTexto = '${clasificacionOriginal.toStringAsFixed(1)}/5';
      } catch (e) {
        print('Error parseando clasificación: $e');
        clasificacionTexto = 'Sin clasificación';
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 16),
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
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFD700),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          clasificacionTexto,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF854937),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sistema de calificación con estrellas
          Row(
            children: [
              const Text(
                'Calificar:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF854937),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStarRating(pasajero.usuarioRut, setModalState),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget para el sistema de calificación con estrellas
  Widget _buildStarRating(String usuarioRut, StateSetter setModalState) {
    // Estado local para la calificación de cada usuario
    final calificacionActual = _calificacionesPasajeros[usuarioRut] ?? 0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final estrella = index + 1;
        final estaSeleccionada = estrella <= calificacionActual;
        
        return GestureDetector(
          onTap: () {
            _actualizarCalificacion(usuarioRut, estrella.toDouble());
            
            // Actualizar el estado del modal para reflejar el cambio
            setModalState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              estaSeleccionada ? Icons.star : Icons.star_border,
              color: estaSeleccionada ? const Color(0xFFFFD700) : Colors.grey[400],
              size: 20,
            ),
          ),
        );
      }),
    );
  }

  Future<void> _actualizarCalificacion(String usuarioRut, double calificacion) async {
    setState(() {
      // Solo actualizar la calificación en el estado local
      // No enviar al servidor hasta que se presione "Guardar"
      _calificacionesPasajeros[usuarioRut] = calificacion;
    });
  }

  Future<void> _confirmarPasajero(String usuarioRut, String nombre) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Pasajero'),
          content: Text('¿Confirmas a $nombre como pasajero?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
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
        final resultado = await ViajeService.confirmarPasajero(viaje.id, usuarioRut);

        if (mounted) {
          setState(() {
            cargando = false;
          });

          if (resultado['success'] == true) {
            setState(() {
              // Actualizar el estado del pasajero en la lista local
              final index = viaje.pasajeros.indexWhere((p) => p.usuarioRut == usuarioRut);
              if (index != -1) {
                final pasajeroActualizado = PasajeroViaje(
                  usuarioRut: viaje.pasajeros[index].usuarioRut,
                  pasajerosSolicitados: viaje.pasajeros[index].pasajerosSolicitados,
                  estado: 'confirmado',
                  fechaSolicitud: viaje.pasajeros[index].fechaSolicitud,
                  mensaje: viaje.pasajeros[index].mensaje,
                  usuario: viaje.pasajeros[index].usuario,
                );
                viaje.pasajeros[index] = pasajeroActualizado;
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pasajero confirmado exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(resultado['message'] ?? 'Error al confirmar pasajero'),
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

  Future<void> _eliminarPasajero(String usuarioRut, String nombre) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Pasajero'),
          content: Text('¿Estás seguro de que quieres eliminar a $nombre del viaje?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
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
        final resultado = await ViajeService.eliminarPasajero(viaje.id, usuarioRut);

        if (mounted) {
          setState(() {
            cargando = false;
          });

          if (resultado['success'] == true) {
            setState(() {
              // Remover el pasajero de la lista local
              viaje.pasajeros.removeWhere((p) => p.usuarioRut == usuarioRut);
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pasajero eliminado exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(resultado['message'] ?? 'Error al eliminar pasajero'),
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

  void _toggleRutaRestante() {
    setState(() {
      mostrarRutaRestante = !mostrarRutaRestante;
    });

    if (mostrarRutaRestante) {
      // Activar el seguimiento de ruta usando el servicio
      RutaService.instance.activarRutaRestante(
        viajeId: viaje.id,
        destinoNombre: viaje.destino.nombre,
        destinoLat: viaje.destino.latitud,
        destinoLng: viaje.destino.longitud,
        esConductor: true,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seguimiento de ruta activado. El mapa mostrará la ruta restante.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      // Desactivar el seguimiento de ruta
      RutaService.instance.desactivarRuta();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seguimiento de ruta desactivado'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _guardarTodasLasCalificaciones() async {
    final calificacionesPendientes = _calificacionesPasajeros.entries
        .where((entry) => entry.value > 0)
        .toList();

    if (calificacionesPendientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay calificaciones para guardar'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF854937)),
          ),
        ),
      );

      int exitosas = 0;
      int fallidas = 0;

      for (final entrada in calificacionesPendientes) {
        try {
          final headers = await TokenManager.getAuthHeaders();
          if (headers == null) {
            fallidas++;
            continue;
          }

          headers['Content-Type'] = 'application/json';

          final response = await http.post(
            Uri.parse('${confGlobal.baseUrl}/user/calificar'),
            headers: headers,
            body: json.encode({
              'rutUsuarioCalificado': entrada.key,
              'calificacion': entrada.value,
            }),
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              exitosas++;
            } else {
              fallidas++;
            }
          } else {
            fallidas++;
          }
        } catch (e) {
          print('Error enviando calificación para ${entrada.key}: $e');
          fallidas++;
        }
      }

      // Cerrar indicador de carga
      Navigator.of(context).pop();

      // Mostrar resultado
      if (exitosas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $exitosas calificación(es) guardada(s) exitosamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      if (fallidas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $fallidas calificación(es) fallaron al guardarse'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      // Cerrar indicador de carga si está abierto
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar calificaciones: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Color palette from perfil.dart
    final Color fondo = Color(0xFFF8F2EF);
    final Color primario = Color(0xFF6B3B2D);
    final Color secundario = Color(0xFF8D4F3A);
    
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Detalle del Viaje'),
        backgroundColor: secundario,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: cargando
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primario),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado del viaje
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
                            _getEstadoColor(viaje.estado).withOpacity(0.1),
                            Colors.white,
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getEstadoColor(viaje.estado).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getEstadoIcon(viaje.estado),
                                color: _getEstadoColor(viaje.estado),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Estado: ${_getEstadoTexto(viaje.estado)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primario,
                              ),
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
                              Icon(
                                Icons.route,
                                color: primario,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Información del Viaje',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primario,
                                ),
                              ),
                              const Spacer(),
                              // Chat Group Button
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
                                  tooltip: 'Chat grupal',
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
                          
                          if (viaje.vehiculo != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(Icons.directions_car, 'Vehículo', 
                              '${viaje.vehiculo!.modelo} - ${viaje.vehiculo!.patente}', primario),
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
                              Text(
                                'Pasajeros',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primario,
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
      child: Column(
        children: [
          Row(
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
                    if (pasajero.mensaje != null && pasajero.mensaje!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.message, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                pasajero.mensaje!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (pasajero.estado == 'pendiente' || pasajero.estado == 'confirmado') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (pasajero.estado == 'pendiente') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmarPasajero(pasajero.usuarioRut, nombre),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Confirmar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _eliminarPasajero(pasajero.usuarioRut, nombre),
                    icon: const Icon(Icons.person_remove, size: 18),
                    label: Text(pasajero.estado == 'confirmado' ? 'Eliminar' : 'Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBotonesAccion() {
    final estado = viaje.estado;
    // Color palette from perfil.dart
    final Color primario = Color(0xFF6B3B2D);
    
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
          activeColor: primario,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),

        const SizedBox(height: 8),
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
                    Icon(
                      Icons.navigation,
                      color: primario,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Navegación',
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
                backgroundColor: primario,
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
      fechaVuelta: fechaVuelta ?? this.fechaVuelta,
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
