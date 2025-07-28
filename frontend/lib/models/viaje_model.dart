class Viaje {
  final String id;
  final String usuarioRut;
  final String vehiculoPatente;
  final UbicacionViaje origen;
  final UbicacionViaje destino;
  final DateTime fechaIda;
  final DateTime? fechaVuelta;
  final bool viajeIdaVuelta;
  final int maxPasajeros;
  final bool soloMujeres;
  final String flexibilidadSalida;
  final double precio;
  final int plazasDisponibles;
  final String? comentarios;
  final List<PasajeroViaje> pasajeros;
  final String estado;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  
  // Datos enriquecidos desde PostgreSQL
  final Conductor? conductor;
  final VehiculoViaje? vehiculo;
  final double? distanciaOrigen;
  final double? distanciaDestino;

  // Propiedades para determinar el tipo de relación del usuario con el viaje
  final bool? esCreador;
  final bool? esUnido;

  Viaje({
    required this.id,
    required this.usuarioRut,
    required this.vehiculoPatente,
    required this.origen,
    required this.destino,
    required this.fechaIda,
    this.fechaVuelta,
    required this.viajeIdaVuelta,
    required this.maxPasajeros,
    required this.soloMujeres,
    required this.flexibilidadSalida,
    required this.precio,
    required this.plazasDisponibles,
    this.comentarios,
    required this.pasajeros,
    required this.estado,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    this.conductor,
    this.vehiculo,
    this.distanciaOrigen,
    this.distanciaDestino,
    this.esCreador,
    this.esUnido,
  });

  // Getters para extraer la hora de las fechas (en hora local de Chile)
  String get horaIda {
    // Convertir UTC a hora de Chile (UTC-4)
    final fechaChile = fechaIda.subtract(const Duration(hours: 4));
    return '${fechaChile.hour.toString().padLeft(2, '0')}:${fechaChile.minute.toString().padLeft(2, '0')}';
  }

  String? get horaVuelta {
    if (fechaVuelta == null) return null;
    // Convertir UTC a hora de Chile (UTC-4)
    final fechaChile = fechaVuelta!.subtract(const Duration(hours: 4));
    return '${fechaChile.hour.toString().padLeft(2, '0')}:${fechaChile.minute.toString().padLeft(2, '0')}';
  }

  // Getters para formatear las fechas (en hora local de Chile)
  String get fechaIdaFormateada {
    // Convertir UTC a hora de Chile (UTC-4)
    final fechaChile = fechaIda.subtract(const Duration(hours: 4));
    return '${fechaChile.day}/${fechaChile.month}/${fechaChile.year}';
  }

  String? get fechaVueltaFormateada {
    if (fechaVuelta == null) return null;
    // Convertir UTC a hora de Chile (UTC-4)
    final fechaChile = fechaVuelta!.subtract(const Duration(hours: 4));
    return '${fechaChile.day}/${fechaChile.month}/${fechaChile.year}';
  }

  factory Viaje.fromJson(Map<String, dynamic> json) {
    return Viaje(
      id: json['_id'] ?? '',
      usuarioRut: json['usuario_rut'] ?? '',
      vehiculoPatente: json['vehiculo_patente'] ?? '',
      origen: UbicacionViaje.fromJson(json['origen']),
      destino: UbicacionViaje.fromJson(json['destino']),
      fechaIda: DateTime.parse(json['fecha_ida']),
      fechaVuelta: json['fecha_vuelta'] != null 
        ? DateTime.parse(json['fecha_vuelta']) 
        : null,
      viajeIdaVuelta: json['viaje_ida_vuelta'] ?? false,
      maxPasajeros: json['max_pasajeros'] ?? 0,
      soloMujeres: json['solo_mujeres'] ?? false,
      flexibilidadSalida: json['flexibilidad_salida'] ?? 'Puntual',
      precio: (json['precio'] ?? 0).toDouble(),
      plazasDisponibles: json['plazas_disponibles'] ?? 0,
      comentarios: json['comentarios'],
      pasajeros: (json['pasajeros'] as List<dynamic>?)
          ?.map((p) => PasajeroViaje.fromJson(p))
          .toList() ?? [],
      estado: json['estado'] ?? 'activo',
      fechaCreacion: DateTime.parse(
        json['fecha_creacion'] ?? DateTime.now().toIso8601String()
      ),
      fechaActualizacion: DateTime.parse(
        json['fecha_actualizacion'] ?? DateTime.now().toIso8601String()
      ),
      conductor: json['conductor'] != null 
        ? Conductor.fromJson(json['conductor']) 
        : null,
      vehiculo: json['vehiculo'] != null 
        ? VehiculoViaje.fromJson(json['vehiculo']) 
        : null,
      distanciaOrigen: json['distancia_origen']?.toDouble(),
      distanciaDestino: json['distancia_destino']?.toDouble(),
      esCreador: json['es_creador'],
      esUnido: json['es_unido'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'usuario_rut': usuarioRut,
      'vehiculo_patente': vehiculoPatente,
      'origen': origen.toJson(),
      'destino': destino.toJson(),
      'fecha_ida': fechaIda.toIso8601String(),
      'fecha_vuelta': fechaVuelta?.toIso8601String(),
      'viaje_ida_vuelta': viajeIdaVuelta,
      'max_pasajeros': maxPasajeros,
      'solo_mujeres': soloMujeres,
      'flexibilidad_salida': flexibilidadSalida,
      'precio': precio,
      'plazas_disponibles': plazasDisponibles,
      'comentarios': comentarios,
      'pasajeros': pasajeros.map((p) => p.toJson()).toList(),
      'estado': estado,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion.toIso8601String(),
      if (conductor != null) 'conductor': conductor!.toJson(),
      if (vehiculo != null) 'vehiculo': vehiculo!.toJson(),
      if (distanciaOrigen != null) 'distancia_origen': distanciaOrigen,
      if (distanciaDestino != null) 'distancia_destino': distanciaDestino,
      if (esCreador != null) 'es_creador': esCreador,
      if (esUnido != null) 'es_unido': esUnido,
    };
  }
}

class UbicacionViaje {
  final String nombre;
  final List<double> coordinates; // [longitud, latitud]

  UbicacionViaje({
    required this.nombre,
    required this.coordinates,
  });

  double get latitud => coordinates[1];
  double get longitud => coordinates[0];

  factory UbicacionViaje.fromJson(Map<String, dynamic> json) {
    return UbicacionViaje(
      nombre: json['nombre'] ?? '',
      coordinates: json['ubicacion'] != null 
        ? List<double>.from(json['ubicacion']['coordinates'])
        : [0.0, 0.0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'ubicacion': {
        'type': 'Point',
        'coordinates': coordinates,
      },
    };
  }
}

class PasajeroViaje {
  final String usuarioRut;
  final String estado;
  final int pasajerosSolicitados;
  final String? mensaje;
  final DateTime fechaSolicitud;
  final Map<String, dynamic>? usuario; // Datos del usuario desde PostgreSQL

  PasajeroViaje({
    required this.usuarioRut,
    required this.estado,
    required this.pasajerosSolicitados,
    this.mensaje,
    required this.fechaSolicitud,
    this.usuario,
  });

  factory PasajeroViaje.fromJson(Map<String, dynamic> json) {
    return PasajeroViaje(
      usuarioRut: json['usuario_rut'] ?? '',
      estado: json['estado'] ?? 'pendiente',
      pasajerosSolicitados: json['pasajeros_solicitados'] ?? 1,
      mensaje: json['mensaje'],
      fechaSolicitud: DateTime.parse(
        json['fecha_solicitud'] ?? DateTime.now().toIso8601String()
      ),
      usuario: json['usuario'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usuario_rut': usuarioRut,
      'estado': estado,
      'pasajeros_solicitados': pasajerosSolicitados,
      'mensaje': mensaje,
      'fecha_solicitud': fechaSolicitud.toIso8601String(),
      if (usuario != null) 'usuario': usuario,
    };
  }
}

class Conductor {
  final String rut;
  final String nombre;
  final String email;

  Conductor({
    required this.rut,
    required this.nombre,
    required this.email,
  });

  factory Conductor.fromJson(Map<String, dynamic> json) {
    return Conductor(
      rut: json['rut'] ?? '',
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rut': rut,
      'nombre': nombre,
      'email': email,
    };
  }
}

class VehiculoViaje {
  final String patente;
  final String modelo;
  final String color;
  final int nroAsientos;
  final String? tipo;

  VehiculoViaje({
    required this.patente,
    required this.modelo,
    required this.color,
    required this.nroAsientos,
    this.tipo,
  });

  factory VehiculoViaje.fromJson(Map<String, dynamic> json) {
    return VehiculoViaje(
      patente: json['patente'] ?? '',
      modelo: json['modelo'] ?? '',
      color: json['color'] ?? '',
      nroAsientos: json['nro_asientos'] ?? 0,
      tipo: json['tipo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patente': patente,
      'modelo': modelo,
      'color': color,
      'nro_asientos': nroAsientos,
      if (tipo != null) 'tipo': tipo,
    };
  }
}

/// Modelo para viajes encontrados por proximidad geográfica
class ViajeProximidad {
  final String id;
  final UbicacionViaje origen;
  final UbicacionViaje destino;
  final DateTime fechaIda; // Cambiado a DateTime
  final double precio;
  final int plazasDisponibles;
  final int maxPasajeros;
  final bool soloMujeres;
  final String vehiculoPatente;
  final String usuarioRut;
  final DistanciasViaje distancias;
  final Conductor? conductor; // Agregamos información del conductor
  final String? comentarios; // Agregamos comentarios del viaje

  ViajeProximidad({
    required this.id,
    required this.origen,
    required this.destino,
    required this.fechaIda,
    required this.precio,
    required this.plazasDisponibles,
    required this.maxPasajeros,
    required this.soloMujeres,
    required this.vehiculoPatente,
    required this.usuarioRut,
    required this.distancias,
    this.conductor,
    this.comentarios,
  });

  // Getter para extraer la hora de la fecha (en hora local de Chile)
  String get horaIda {
    // Convertir UTC a hora de Chile (UTC-4)
    final fechaChile = fechaIda.subtract(const Duration(hours: 4));
    return '${fechaChile.hour.toString().padLeft(2, '0')}:${fechaChile.minute.toString().padLeft(2, '0')}';
  }

  // Getter para formatear la fecha (en hora local de Chile)
  String get fechaIdaFormateada {
    // Convertir UTC a hora de Chile (UTC-4)
    final fechaChile = fechaIda.subtract(const Duration(hours: 4));
    return '${fechaChile.day}/${fechaChile.month}/${fechaChile.year}';
  }

  factory ViajeProximidad.fromJson(Map<String, dynamic> json) {
    return ViajeProximidad(
      id: json['_id'] ?? json['id'] ?? '',  // Probar tanto _id como id
      origen: UbicacionViaje.fromJson(json['origen'] ?? {}),
      destino: UbicacionViaje.fromJson(json['destino'] ?? {}),
      fechaIda: DateTime.parse(json['fecha_ida']),
      precio: (json['precio'] ?? 0).toDouble(),
      plazasDisponibles: json['plazas_disponibles'] ?? 0,
      maxPasajeros: json['max_pasajeros'] ?? 0,
      soloMujeres: json['solo_mujeres'] ?? false,
      vehiculoPatente: json['vehiculo_patente'] ?? '',
      usuarioRut: json['usuario_rut'] ?? '',
      distancias: DistanciasViaje.fromJson(json['distancias'] ?? {}),
      conductor: json['conductor'] != null ? Conductor.fromJson(json['conductor']) : null,
      comentarios: json['comentarios'], // Agregar parsing de comentarios
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'origen': origen.toJson(),
      'destino': destino.toJson(),
      'fecha_ida': fechaIda.toIso8601String(),
      'precio': precio,
      'plazas_disponibles': plazasDisponibles,
      'max_pasajeros': maxPasajeros,
      'solo_mujeres': soloMujeres,
      'vehiculo_patente': vehiculoPatente,
      'usuario_rut': usuarioRut,
      'distancias': distancias.toJson(),
    };
  }
}

/// Modelo para las distancias calculadas en la búsqueda por proximidad
class DistanciasViaje {
  final int origenMetros;
  final int destinoMetros;
  final int totalCaminataMetros;
  final double origenKm;
  final double destinoKm;

  DistanciasViaje({
    required this.origenMetros,
    required this.destinoMetros,
    required this.totalCaminataMetros,
    required this.origenKm,
    required this.destinoKm,
  });

  factory DistanciasViaje.fromJson(Map<String, dynamic> json) {
    return DistanciasViaje(
      origenMetros: json['origenMetros'] ?? 0,
      destinoMetros: json['destinoMetros'] ?? 0,
      totalCaminataMetros: json['totalCaminataMetros'] ?? 0,
      origenKm: (json['origenKm'] ?? 0.0).toDouble(),
      destinoKm: (json['destinoKm'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'origenMetros': origenMetros,
      'destinoMetros': destinoMetros,
      'totalCaminataMetros': totalCaminataMetros,
      'origenKm': origenKm,
      'destinoKm': destinoKm,
    };
  }
}
