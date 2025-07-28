class Notificacion {
  final String id;
  final String titulo;
  final String mensaje;
  final String tipo;
  final DateTime fechaCreacion;
  final bool leida;
  final Map<String, dynamic>? datos;

  Notificacion({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.fechaCreacion,
    required this.leida,
    this.datos,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    try {
      return Notificacion(
        id: json['_id']?.toString() ?? '',
        titulo: json['titulo']?.toString() ?? '',
        mensaje: json['mensaje']?.toString() ?? '',
        tipo: json['tipo']?.toString() ?? '',
        fechaCreacion: DateTime.parse(json['fechaCreacion'] ?? DateTime.now().toIso8601String()),
        leida: json['leida'] ?? false,
        datos: json['datos'],
      );
    } catch (e) {
      print('Error al parsear notificación: $e');
      print('JSON recibido: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'titulo': titulo,
      'mensaje': mensaje,
      'tipo': tipo,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'leida': leida,
      'datos': datos,
    };
  }

  // Getters para información específica de solicitudes de viaje
  String? get viajeId => datos?['viajeId'];
  String? get solicitanteId => datos?['solicitanteId'];
  String? get solicitanteNombre => datos?['solicitanteNombre'];
  String? get origen => datos?['origen'];
  String? get destino => datos?['destino'];
  double? get precio => datos?['precio']?.toDouble();
  String? get fechaViaje => datos?['fechaViaje'];
  String? get horaViaje => datos?['horaViaje'];
  
  bool get esSolicitudViaje => tipo == 'solicitud_viaje';
}
