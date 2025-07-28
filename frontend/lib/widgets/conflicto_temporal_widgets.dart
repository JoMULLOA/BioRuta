import 'package:flutter/material.dart';

class ConflictoTemporalDialog extends StatelessWidget {
  final String tipoConflicto;
  final String mensaje;
  final Map<String, dynamic>? detallesConflicto;
  final VoidCallback? onAceptar;
  final VoidCallback? onCancelar;

  const ConflictoTemporalDialog({
    Key? key,
    required this.tipoConflicto,
    required this.mensaje,
    this.detallesConflicto,
    this.onAceptar,
    this.onCancelar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Row(
        children: [
          Icon(
            _getIconoConflicto(),
            color: _getColorConflicto(),
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _getTituloConflicto(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mensaje,
            style: const TextStyle(fontSize: 16),
          ),
          if (detallesConflicto != null) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    width: 4,
                    color: _getColorConflicto(),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalles del conflicto:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getColorConflicto(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._construirDetalles(),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (onCancelar != null)
          TextButton(
            onPressed: onCancelar,
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ElevatedButton(
          onPressed: onAceptar ?? () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _getColorConflicto(),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Entendido'),
        ),
      ],
    );
  }

  IconData _getIconoConflicto() {
    switch (tipoConflicto) {
      case 'solapamiento_temporal':
        return Icons.schedule_outlined;
      case 'conductor_unido_a_viaje':
        return Icons.car_rental;
      case 'tiempo_traslado_insuficiente':
        return Icons.location_on_outlined;
      default:
        return Icons.warning_outlined;
    }
  }

  Color _getColorConflicto() {
    switch (tipoConflicto) {
      case 'solapamiento_temporal':
        return Colors.orange;
      case 'conductor_unido_a_viaje':
        return Colors.red;
      case 'tiempo_traslado_insuficiente':
        return Colors.blue;
      default:
        return Colors.red;
    }
  }

  String _getTituloConflicto() {
    switch (tipoConflicto) {
      case 'solapamiento_temporal':
        return 'Conflicto de Horarios';
      case 'conductor_unido_a_viaje':
        return 'No Puedes Conducir';
      case 'tiempo_traslado_insuficiente':
        return 'Tiempo Insuficiente';
      default:
        return 'Conflicto Detectado';
    }
  }

  List<Widget> _construirDetalles() {
    if (detallesConflicto == null) return [];

    List<Widget> detalles = [];

    if (detallesConflicto!.containsKey('viajeConflicto')) {
      detalles.add(
        Row(
          children: [
            Icon(Icons.trip_origin, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Viaje en conflicto: ${detallesConflicto!['viajeConflicto']}',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      );
    }

    if (detallesConflicto!.containsKey('tiempoDisponible')) {
      detalles.add(
        const SizedBox(height: 4),
      );
      detalles.add(
        Row(
          children: [
            Icon(Icons.timer, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tiempo disponible: ${detallesConflicto!['tiempoDisponible']} min',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      );
    }

    if (detallesConflicto!.containsKey('tiempoNecesario')) {
      detalles.add(
        const SizedBox(height: 4),
      );
      detalles.add(
        Row(
          children: [
            Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tiempo necesario: ${detallesConflicto!['tiempoNecesario']} min',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      );
    }

    return detalles;
  }
}

/// Widget para mostrar una alerta mejorada de conflictos
class ConflictoTemporalSnackBar {
  static void mostrar(
    BuildContext context, {
    required String tipoConflicto,
    required String mensaje,
    Map<String, dynamic>? detallesConflicto,
    VoidCallback? onDetalles,
  }) {
    final color = _getColorConflicto(tipoConflicto);
    final icono = _getIconoConflicto(tipoConflicto);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icono, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTituloConflicto(tipoConflicto),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mensaje,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: onDetalles != null
            ? SnackBarAction(
                label: 'Detalles',
                textColor: Colors.white,
                onPressed: onDetalles,
              )
            : null,
      ),
    );
  }

  static IconData _getIconoConflicto(String tipoConflicto) {
    switch (tipoConflicto) {
      case 'solapamiento_temporal':
        return Icons.schedule_outlined;
      case 'conductor_unido_a_viaje':
        return Icons.car_rental;
      case 'tiempo_traslado_insuficiente':
        return Icons.location_on_outlined;
      default:
        return Icons.warning_outlined;
    }
  }

  static Color _getColorConflicto(String tipoConflicto) {
    switch (tipoConflicto) {
      case 'solapamiento_temporal':
        return Colors.orange;
      case 'conductor_unido_a_viaje':
        return Colors.red;
      case 'tiempo_traslado_insuficiente':
        return Colors.blue;
      default:
        return Colors.red;
    }
  }

  static String _getTituloConflicto(String tipoConflicto) {
    switch (tipoConflicto) {
      case 'solapamiento_temporal':
        return 'Conflicto de Horarios';
      case 'conductor_unido_a_viaje':
        return 'No Puedes Conducir';
      case 'tiempo_traslado_insuficiente':
        return 'Tiempo Insuficiente';
      default:
        return 'Conflicto Detectado';
    }
  }
}
