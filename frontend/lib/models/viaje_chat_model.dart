class ViajeChat {
  final String idViaje;
  final String origen;
  final String destino;
  final DateTime? fechaViaje;
  final String? horaViaje;
  final String conductorNombre;
  final String conductorRut;
  final int cantidadPasajeros;
  final bool soyElConductor;
  final String estado;

  ViajeChat({
    required this.idViaje,
    required this.origen,
    required this.destino,
    this.fechaViaje,
    this.horaViaje,
    required this.conductorNombre,
    required this.conductorRut,
    required this.cantidadPasajeros,
    required this.soyElConductor,
    required this.estado,
  });

  factory ViajeChat.fromJson(Map<String, dynamic> json) {
    // Extraer origen y destino que pueden venir como objetos
    String origenNombre = '';
    String destinoNombre = '';
    
    if (json['origen'] is Map<String, dynamic>) {
      origenNombre = json['origen']['nombre'] ?? 'Origen no especificado';
    } else if (json['origen'] is String) {
      origenNombre = json['origen'];
    }
    
    if (json['destino'] is Map<String, dynamic>) {
      destinoNombre = json['destino']['nombre'] ?? 'Destino no especificado';
    } else if (json['destino'] is String) {
      destinoNombre = json['destino'];
    }

    // Parsear fecha
    DateTime? fechaViaje;
    try {
      if (json['fecha_ida'] != null) {
        fechaViaje = DateTime.parse(json['fecha_ida']);
      }
    } catch (e) {
      print('Error parsing fecha_ida: $e');
    }

    // Extraer conductor
    String conductorNombre = 'Conductor desconocido';
    String conductorRut = '';
    
    if (json['conductor'] is Map<String, dynamic>) {
      conductorNombre = json['conductor']['nombre'] ?? json['conductor']['nombreCompleto'] ?? 'Conductor desconocido';
      conductorRut = json['conductor']['rut'] ?? '';
    } else if (json['usuario_rut'] != null) {
      conductorRut = json['usuario_rut'];
      // Si tenemos el RUT pero no el nombre, usar un nombre genérico
      conductorNombre = 'Conductor';
    }

    // Contar pasajeros confirmados
    int cantidadPasajeros = 0;
    if (json['pasajeros'] is List) {
      final pasajeros = json['pasajeros'] as List;
      cantidadPasajeros = pasajeros.where((p) => p['estado'] == 'confirmado').length;
    }

    return ViajeChat(
      idViaje: json['_id'] ?? '',
      origen: origenNombre,
      destino: destinoNombre,
      fechaViaje: fechaViaje,
      horaViaje: json['hora_ida'],
      conductorNombre: conductorNombre,
      conductorRut: conductorRut,
      cantidadPasajeros: cantidadPasajeros,
      soyElConductor: false, // Se determinará más tarde
      estado: json['estado'] ?? 'activo',
    );
  }

  // Getter para mostrar la ruta completa
  String get rutaCompleta => '$origen → $destino';

  // Getter para mostrar fecha formateada
  String get fechaFormateada {
    if (fechaViaje == null) return 'Fecha no definida';
    
    final meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    
    return '${fechaViaje!.day} ${meses[fechaViaje!.month - 1]}';
  }

  // Getter para mostrar información del conductor
  String get infoTitulo {
    return soyElConductor ? 'Tu viaje' : 'Viaje de $conductorNombre';
  }

  // Getter para mostrar subtítulo con pasajeros
  String get infoSubtitulo {
    final pasajerosText = cantidadPasajeros == 1 ? '1 pasajero' : '$cantidadPasajeros pasajeros';
    final fechaHora = horaViaje != null ? '$fechaFormateada a las $horaViaje' : fechaFormateada;
    return '$pasajerosText • $fechaHora';
  }
}
