import 'package:flutter/material.dart';
import '../services/notificacion_service.dart';
import '../services/websocket_notification_service.dart';
import '../mis_viajes/solicitudes_pasajeros_modal.dart';

class SolicitudesButtonWidget extends StatefulWidget {
  final VoidCallback? onSolicitudProcesada;
  final VoidCallback? onContadorCambiado;
  final bool showAsFloatingButton;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;
  final String? label;

  const SolicitudesButtonWidget({
    super.key,
    this.onSolicitudProcesada,
    this.onContadorCambiado,
    this.showAsFloatingButton = true,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.label,
  });

  @override
  State<SolicitudesButtonWidget> createState() => _SolicitudesButtonWidgetState();
}

class _SolicitudesButtonWidgetState extends State<SolicitudesButtonWidget> {
  int numeroSolicitudesPendientes = 0;
  bool _cargandoSolicitudes = false;

  @override
  void initState() {
    super.initState();
    _cargarSolicitudesPendientes();
    
    // Registrar callback para actualizaciones automáticas de solicitudes
    WebSocketNotificationService.setOnTripRequestReceived(() {
      if (mounted) {
        _cargarSolicitudesPendientes();
      }
    });
    
    WebSocketNotificationService.setOnTripRequestProcessed(() {
      if (mounted) {
        _cargarSolicitudesPendientes();
      }
    });
  }

  Future<void> _cargarSolicitudesPendientes() async {
    if (_cargandoSolicitudes) return;
    
    setState(() {
      _cargandoSolicitudes = true;
    });

    try {
      final numero = await NotificacionService.obtenerNumeroNotificacionesPendientes();
      if (mounted) {
        setState(() {
          numeroSolicitudesPendientes = numero;
          _cargandoSolicitudes = false;
        });
      }
    } catch (e) {
      print('Error al cargar solicitudes pendientes: $e');
      if (mounted) {
        setState(() {
          _cargandoSolicitudes = false;
        });
      }
    }
  }

  void _mostrarSolicitudesPasajeros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SolicitudesPasajerosModal(
        onSolicitudProcesada: () {
          // Recargar el contador local
          _cargarSolicitudesPendientes();
          
          // Llamar al callback externo si existe
          widget.onSolicitudProcesada?.call();
        },
        onContadorCambiado: () {
          // Recargar el contador cuando haya cambios automáticos
          _cargarSolicitudesPendientes();
          
          // Llamar al callback externo si existe
          widget.onContadorCambiado?.call();
        },
      ),
    ).then((_) {
      // Recargar solicitudes al cerrar el modal
      if (mounted) {
        _cargarSolicitudesPendientes();
      }
    });
  }

  Widget _buildBadge() {
    if (numeroSolicitudesPendientes <= 0) return const SizedBox.shrink();
    
    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 1),
        ),
        constraints: const BoxConstraints(
          minWidth: 16,
          minHeight: 16,
        ),
        child: Text(
          numeroSolicitudesPendientes > 99 ? '99+' : '$numeroSolicitudesPendientes',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay solicitudes pendientes y se configuró para ocultarse, no mostrar nada
    if (numeroSolicitudesPendientes == 0 && widget.showAsFloatingButton) {
      return const SizedBox.shrink();
    }

    if (widget.showAsFloatingButton) {
      return FloatingActionButton.extended(
        onPressed: _mostrarSolicitudesPasajeros,
        backgroundColor: widget.backgroundColor ?? const Color(0xFF854937),
        foregroundColor: widget.foregroundColor ?? Colors.white,
        icon: Stack(
          children: [
            Icon(widget.icon ?? Icons.notifications),
            _buildBadge(),
          ],
        ),
        label: Text(
          widget.label ?? 'Solicitudes${numeroSolicitudesPendientes > 0 ? ' ($numeroSolicitudesPendientes)' : ''}',
        ),
      );
    } else {
      // Botón regular para otras pantallas
      return ElevatedButton.icon(
        onPressed: _mostrarSolicitudesPasajeros,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.backgroundColor ?? const Color(0xFF854937),
          foregroundColor: widget.foregroundColor ?? Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: Stack(
          children: [
            Icon(widget.icon ?? Icons.notifications, size: 20),
            _buildBadge(),
          ],
        ),
        label: Text(
          widget.label ?? 'Ver Solicitudes${numeroSolicitudesPendientes > 0 ? ' ($numeroSolicitudesPendientes)' : ''}',
        ),
      );
    }
  }
  
  @override
  void dispose() {
    // Limpiar callbacks cuando el widget se destruye
    WebSocketNotificationService.setOnTripRequestReceived(null);
    WebSocketNotificationService.setOnTripRequestProcessed(null);
    super.dispose();
  }
}
