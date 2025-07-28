import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/notificacion_model.dart';
import '../services/notificacion_service.dart';

class SolicitudesPasajerosModal extends StatefulWidget {
  final VoidCallback? onSolicitudProcesada;
  final VoidCallback? onContadorCambiado; // Nuevo callback para cambios en el contador
  
  const SolicitudesPasajerosModal({
    super.key,
    this.onSolicitudProcesada,
    this.onContadorCambiado,
  });

  @override
  State<SolicitudesPasajerosModal> createState() => _SolicitudesPasajerosModalState();
}

class _SolicitudesPasajerosModalState extends State<SolicitudesPasajerosModal> {
  List<Notificacion> solicitudes = [];
  bool cargando = true;
  Timer? _timerActualizacion;
  DateTime? _ultimaActualizacion;

  @override
  void initState() {
    super.initState();
    _cargarSolicitudes();
    _iniciarActualizacionAutomatica();
  }

  @override
  void dispose() {
    _timerActualizacion?.cancel();
    super.dispose();
  }

  void _iniciarActualizacionAutomatica() {
    // Iniciar con un timer más agresivo para solicitudes críticas
    _timerActualizacion = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        _cargarSolicitudes(mostrarCarga: false);
      }
    });
  }

  Future<void> _cargarSolicitudes({bool mostrarCarga = true}) async {
    try {
      if (mostrarCarga) {
        setState(() {
          cargando = true;
        });
      }

      final resultado = await NotificacionService.obtenerNotificacionesPendientes();
      
      if (resultado['success'] == true) {
        final List<dynamic> notificacionesData = resultado['data'] ?? [];
        final nuevasSolicitudes = notificacionesData
            .map((notif) => Notificacion.fromJson(notif))
            .where((notif) => notif.esSolicitudViaje)
            .toList();
        
        // Solo actualizar si hay cambios o es la primera carga
        if (mostrarCarga || solicitudes.length != nuevasSolicitudes.length ||
            !_sonIgualesSolicitudes(solicitudes, nuevasSolicitudes)) {
          
          final int contadorAnterior = solicitudes.length;
          final DateTime ahora = DateTime.now();
          
          setState(() {
            solicitudes = nuevasSolicitudes;
            _ultimaActualizacion = ahora;
            if (mostrarCarga) {
              cargando = false;
            }
          });

          // Notificar cambios en el contador al padre
          if (contadorAnterior != nuevasSolicitudes.length) {
            widget.onContadorCambiado?.call();
          }

          // Si hay nuevas solicitudes, hacer vibración (solo en actualizaciones automáticas)
          if (!mostrarCarga && nuevasSolicitudes.length > contadorAnterior) {
            HapticFeedback.lightImpact();
            print('🔔 Nueva solicitud detectada! Total: ${nuevasSolicitudes.length}');
          }
        } else if (!mostrarCarga) {
          // Actualizar timestamp aunque no haya cambios
          setState(() {
            _ultimaActualizacion = DateTime.now();
          });
        }
      } else {
        if (mostrarCarga) {
          setState(() {
            cargando = false;
          });
        }
        if (mounted && mostrarCarga) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['message'] ?? 'Error al cargar solicitudes'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mostrarCarga) {
        setState(() {
          cargando = false;
        });
      }
      if (mounted && mostrarCarga) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar solicitudes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _responderSolicitud(Notificacion solicitud, bool aceptar) async {
    try {
      final resultado = await NotificacionService.responderSolicitudViaje(
        notificacionId: solicitud.id,
        aceptar: aceptar,
      );

      if (resultado['success'] == true) {
        // Recargar las solicitudes
        await _cargarSolicitudes();
        
        // Llamar al callback si está disponible
        widget.onSolicitudProcesada?.call();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['message'] ?? 
                (aceptar ? 'Solicitud aceptada' : 'Solicitud rechazada')),
              backgroundColor: aceptar ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['message'] ?? 'Error al procesar la respuesta'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al responder solicitud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F2EF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header mejorado
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF8D4F3A),
                  const Color(0xFF6B3B2D),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Solicitudes de Pasajeros',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _ultimaActualizacion != null 
                                ? 'Actualizado hace ${DateTime.now().difference(_ultimaActualizacion!).inSeconds}s'
                                : 'Actualización automática',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          
          // Contenido mejorado
          Expanded(
            child: cargando
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF854937).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF854937)),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Cargando solicitudes...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF854937),
                          ),
                        ),
                      ],
                    ),
                  )
                : solicitudes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Icon(
                                Icons.inbox,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'No hay solicitudes pendientes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF854937),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Las nuevas solicitudes aparecerán aquí\nautomáticamente',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF6B3B2D),
                        onRefresh: () => _cargarSolicitudes(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: solicitudes.length,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final solicitud = solicitudes[index];
                            return _buildSolicitudCard(solicitud);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudCard(Notificacion solicitud) {
    // Color palette from perfil.dart
    final Color primario = Color(0xFF6B3B2D);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primario.withOpacity(0.2), width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              primario.withOpacity(0.02),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header mejorado con info del solicitante
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primario.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primario.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_add_alt_1,
                      color: primario,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          solicitud.solicitanteNombre ?? 'Usuario desconocido',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF854937),
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Quiere unirse a tu viaje',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primario.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatearTiempo(solicitud.fechaCreacion),
                      style: TextStyle(
                        fontSize: 11,
                        color: primario,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Info del viaje mejorada
              if (solicitud.origen != null && solicitud.destino != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primario.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primario.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Origen',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  solicitud.origen!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Destino',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  solicitud.destino!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Información del precio y detalles del viaje
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green[50]!,
                      Colors.green[100]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.attach_money,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pago del pasajero',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '\$${solicitud.precio?.toInt() ?? 0}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (solicitud.fechaViaje != null) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            solicitud.fechaViaje!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (solicitud.horaViaje != null)
                            Text(
                              solicitud.horaViaje!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Mensaje del pasajero (opcional)
              if (solicitud.mensaje.isNotEmpty && solicitud.mensaje.toLowerCase() != 'sin mensaje') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primario.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primario.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 16,
                            color: primario,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Mensaje:',
                            style: TextStyle(
                              fontSize: 12,
                              color: primario,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        solicitud.mensaje,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Botones de acción mejorados
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            Colors.red[400]!,
                            Colors.red[600]!,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _responderSolicitud(solicitud, false),
                        icon: const Icon(Icons.close, size: 20),
                        label: const Text(
                          'Rechazar',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            Colors.green[400]!,
                            Colors.green[600]!,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _responderSolicitud(solicitud, true),
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text(
                          'Aceptar',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
    );
  }

  // Método para comparar si dos listas de solicitudes son iguales
  bool _sonIgualesSolicitudes(List<Notificacion> lista1, List<Notificacion> lista2) {
    if (lista1.length != lista2.length) return false;
    
    for (int i = 0; i < lista1.length; i++) {
      if (lista1[i].id != lista2[i].id) return false;
    }
    
    return true;
  }

  String _formatearTiempo(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 1) {
      return 'Ahora';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes}m';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours}h';
    } else {
      return 'Hace ${diferencia.inDays}d';
    }
  }
}
