import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/viaje_service.dart';

/// Servicio para verificar automáticamente los estados de los viajes
class ViajeStateMonitor {
  static ViajeStateMonitor? _instance;
  static ViajeStateMonitor get instance => _instance ??= ViajeStateMonitor._();
  
  ViajeStateMonitor._();
  
  Timer? _timer;
  bool _isRunning = false;
  
  /// Iniciar el monitoreo automático de estados de viajes
  void iniciarMonitoreo() {
    if (_isRunning) return;
    
    _isRunning = true;
    debugPrint('🕒 Iniciando monitoreo automático de estados de viajes');
    
    // Verificar cada 2 minutos
    _timer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _verificarViajesPasados();
    });
    
    // Verificar inmediatamente al iniciar
    _verificarViajesPasados();
  }
  
  /// Detener el monitoreo
  void detenerMonitoreo() {
    if (!_isRunning) return;
    
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    debugPrint('🕒 Monitoreo de estados de viajes detenido');
  }
  
  /// Verificar viajes que ya pasaron su hora de salida
  Future<void> _verificarViajesPasados() async {
    try {
      debugPrint('🕒 Verificando viajes que pasaron su hora de salida...');
      
      // Obtener viajes activos del usuario
      final viajesActivos = await ViajeService.obtenerViajesActivosUsuario();
      
      final ahora = DateTime.now();
      int viajesCambiados = 0;
      
      for (final viaje in viajesActivos) {
        try {
          final fechaViaje = DateTime.parse(viaje['fecha_ida']);
          // Convertir UTC a hora chilena
          final fechaChile = fechaViaje.subtract(const Duration(hours: 4));
          
          // Si ya pasó la hora de salida (+5 minutos de gracia)
          if (fechaChile.add(const Duration(minutes: 5)).isBefore(ahora)) {
            final viajeId = viaje['_id'];
            debugPrint('🕒 Viaje $viajeId pasó su hora de salida, cambiando a en_curso');
            
            // Cambiar estado automáticamente
            ViajeService.cambiarEstadoViajeAsincrono(viajeId, 'en_curso');
            viajesCambiados++;
          }
        } catch (e) {
          debugPrint('❌ Error procesando viaje individual: $e');
        }
      }
      
      if (viajesCambiados > 0) {
        debugPrint('✅ $viajesCambiados viajes cambiados automáticamente a en_curso');
      }
      
    } catch (e) {
      debugPrint('❌ Error en verificación automática de viajes: $e');
    }
  }
  
  /// Verificar inmediatamente (llamada manual)
  Future<void> verificarAhora() async {
    await _verificarViajesPasados();
  }
  
  /// Estado del monitoreo
  bool get estaActivo => _isRunning;
}
