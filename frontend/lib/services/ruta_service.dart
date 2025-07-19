class RutaService {
  static RutaService? _instance;
  static RutaService get instance => _instance ??= RutaService._();
  
  RutaService._();

  // Estado de la ruta activa
  bool _rutaActiva = false;
  Map<String, dynamic>? _datosRuta;
  
  // Callback para notificar cambios al mapa
  Function(bool, Map<String, dynamic>?)? _onRutaChanged;

  // Getters
  bool get rutaActiva => _rutaActiva;
  Map<String, dynamic>? get datosRuta => _datosRuta;

  // Registrar el callback del mapa
  void registrarMapaCallback(Function(bool, Map<String, dynamic>?) callback) {
    _onRutaChanged = callback;
  }

  // Activar ruta restante
  void activarRutaRestante({
    required String viajeId,
    required String destinoNombre,
    required double destinoLat,
    required double destinoLng,
    required bool esConductor,
  }) {
    _rutaActiva = true;
    _datosRuta = {
      'viajeId': viajeId,
      'destino': {
        'nombre': destinoNombre,
        'lat': destinoLat,
        'lng': destinoLng,
      },
      'esConductor': esConductor,
      'tipo': 'rutaRestante',
    };
    
    // Notificar al mapa si está registrado
    _onRutaChanged?.call(_rutaActiva, _datosRuta);
    
    print('🗺️ Ruta restante activada: $_datosRuta');
  }

  // Desactivar ruta
  void desactivarRuta() {
    _rutaActiva = false;
    _datosRuta = null;
    
    // Notificar al mapa si está registrado
    _onRutaChanged?.call(_rutaActiva, _datosRuta);
    
    print('🗺️ Ruta desactivada');
  }

  // Verificar si hay una ruta activa para un viaje específico
  bool tieneRutaActiva(String viajeId) {
    return _rutaActiva && _datosRuta?['viajeId'] == viajeId;
  }

  // Limpiar callback (cuando el mapa se destruye)
  void limpiarCallback() {
    _onRutaChanged = null;
  }
}
