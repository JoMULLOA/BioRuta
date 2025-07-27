import 'package:flutter/material.dart';

class MapaUIComponents {
  /// Barra superior estilo Uber
  static Widget buildBarraSuperiorUber({
    required String regionActual,
    required String? destinoSeleccionado,
    required VoidCallback onTap,
    required bool mostrarBotonUber,
    String? origenSeleccionado,
  }) {
    if (!mostrarBotonUber) return const SizedBox.shrink();

    final origenTexto = origenSeleccionado ?? regionActual;

    return Positioned(
      top: 20, // Movido más arriba para mejor visibilidad
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '¿A dónde vas?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (destinoSeleccionado != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Desde $origenTexto → $destinoSeleccionado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'Desde $origenTexto',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón flotante para activar radar
  static Widget buildBotonRadar({
    required bool radarActivo,
    required VoidCallback onPressed,
  }) {
    return Positioned(
      bottom: 120, // Más separación por el tamaño más grande
      right: 16,
      child: FloatingActionButton( // Tamaño más grande
        heroTag: 'radar', // Agregar heroTag para evitar conflictos
        onPressed: onPressed,
        backgroundColor: radarActivo ? Colors.red : const Color(0xFF8D4F3A), // Fondo café
        foregroundColor: Colors.white, // Contenido blanco
        tooltip: 'Activar radar de viajes',
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: radarActivo
              ? const Icon(
                  Icons.stop,
                  key: ValueKey('stop'),
                  size: 28, // Icono más grande
                )
              : const Icon(
                  Icons.radar,
                  key: ValueKey('radar'),
                  size: 28, // Icono más grande
                ),
        ),
      ),
    );
  }

  /// Información del viaje seleccionado
  static Widget buildInfoViajeSeleccionado({
    required Map<String, dynamic> viaje,
    required VoidCallback onSolicitarViaje,
    required VoidCallback onCancelar,
  }) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Info del conductor
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFF854937),
                  child: Text(
                    viaje['conductor']?[0]?.toUpperCase() ?? 'C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viaje['conductor'] ?? 'Conductor',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${viaje['marca'] ?? 'Vehículo'} ${viaje['modelo'] ?? ''} ${viaje['color'] ?? ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${viaje['precio'] ?? '0'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF854937),
                      ),
                    ),
                    Text(
                      '${viaje['plazas_disponibles'] ?? 0} asientos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Ruta
            Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF854937),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 30,
                      color: Colors.grey[300],
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF854937),
                        shape: BoxShape.rectangle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viaje['origen']?['nombre'] ?? 'Origen',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        viaje['destino']?['nombre'] ?? 'Destino',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancelar,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF854937)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: Color(0xFF854937),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onSolicitarViaje,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF854937),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Solicitar viaje',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Indicador de carga
  static Widget buildIndicadorCarga({
    required String mensaje,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Color(0xFF854937)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            mensaje,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Botón de ubicación actual
  static Widget buildBotonUbicacionActual({
    required VoidCallback onPressed,
  }) {
    return Positioned(
      bottom: 40, // Abajo del todo en la esquina inferior derecha
      right: 16,
      child: FloatingActionButton( // Tamaño más grande
        heroTag: 'ubicacion', // Agregar heroTag para evitar conflictos
        onPressed: onPressed,
        backgroundColor: const Color(0xFF8D4F3A), // Fondo café
        foregroundColor: Colors.white, // Contenido blanco
        tooltip: 'Centrar en mi ubicación',
        child: const Icon(
          Icons.my_location,
          size: 28, // Icono más grande
        ),
      ),
    );
  }

  /// Overlay de búsqueda activa
  static Widget buildOverlayBusqueda({
    required String mensaje,
    VoidCallback? onCancelar,
  }) {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF854937)),
              ),
              const SizedBox(height: 16),
              Text(
                mensaje,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (onCancelar != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onCancelar,
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Color(0xFF854937),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Snackbar personalizado
  static void mostrarSnackbar(
    BuildContext context,
    String mensaje, {
    Color backgroundColor = const Color(0xFF854937),
    Duration duration = const Duration(seconds: 3),
    IconData? icono,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icono != null) ...[
              Icon(icono, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
