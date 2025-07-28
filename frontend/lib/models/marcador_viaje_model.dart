class MarcadorViaje {
  final String id;
  final UbicacionMarcador origen;
  final UbicacionMarcador destino;
  final DetallesViaje detallesViaje;

  MarcadorViaje({
    required this.id,
    required this.origen,
    required this.destino,
    required this.detallesViaje,
  });

  factory MarcadorViaje.fromJson(Map<String, dynamic> json) {
    return MarcadorViaje(
      id: json['id'] ?? '',
      origen: UbicacionMarcador.fromJson(json['origen']),
      destino: UbicacionMarcador.fromJson(json['destino']),
      detallesViaje: DetallesViaje.fromJson(json['detalles_viaje']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'origen': origen.toJson(),
      'destino': destino.toJson(),
      'detalles_viaje': detallesViaje.toJson(),
    };
  }
}

class UbicacionMarcador {
  final List<double> coordinates; // [lon, lat]
  final String nombre;

  UbicacionMarcador({
    required this.coordinates,
    required this.nombre,
  });

  factory UbicacionMarcador.fromJson(Map<String, dynamic> json) {
    return UbicacionMarcador(
      coordinates: List<double>.from(json['coordinates']),
      nombre: json['nombre'] ?? '',
    );
  }

  double get latitud => coordinates[1];
  double get longitud => coordinates[0];

  Map<String, dynamic> toJson() {
    return {
      'coordinates': coordinates,
      'nombre': nombre,
    };
  }
}

class DetallesViaje {
  final DateTime fecha;
  final double precio;
  final int plazasDisponibles;
  final VehiculoMarcador? vehiculo;
  final ConductorMarcador? conductor;

  DetallesViaje({
    required this.fecha,
    required this.precio,
    required this.plazasDisponibles,
    this.vehiculo,
    this.conductor,
  });

  /// Getter para extraer la hora de la fecha en formato HH:mm (en hora local de Chile)
  String get hora {
    // Convertir UTC a hora de Chile (UTC-4)
    final fechaChile = fecha.subtract(const Duration(hours: 4));
    return '${fechaChile.hour.toString().padLeft(2, '0')}:${fechaChile.minute.toString().padLeft(2, '0')}';
  }

  factory DetallesViaje.fromJson(Map<String, dynamic> json) {
    return DetallesViaje(
      fecha: DateTime.parse(json['fecha']),
      precio: (json['precio'] ?? 0).toDouble(),
      plazasDisponibles: json['plazas_disponibles'] ?? 0,
      vehiculo: json['vehiculo'] != null 
        ? VehiculoMarcador.fromJson(json['vehiculo']) 
        : null,
      conductor: json['conductor'] != null 
        ? ConductorMarcador.fromJson(json['conductor']) 
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fecha': fecha.toIso8601String(),
      'precio': precio,
      'plazas_disponibles': plazasDisponibles,
      if (vehiculo != null) 'vehiculo': vehiculo!.toJson(),
      if (conductor != null) 'conductor': conductor!.toJson(),
    };
  }
}

class VehiculoMarcador {
  final String patente;
  final String modelo;
  final String color;
  final int nroAsientos;
  final String? tipo;

  VehiculoMarcador({
    required this.patente,
    required this.modelo,
    required this.color,
    required this.nroAsientos,
    this.tipo,
  });

  factory VehiculoMarcador.fromJson(Map<String, dynamic> json) {
    return VehiculoMarcador(
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

class ConductorMarcador {
  final String rut;
  final String nombre;

  ConductorMarcador({
    required this.rut,
    required this.nombre,
  });

  factory ConductorMarcador.fromJson(Map<String, dynamic> json) {
    return ConductorMarcador(
      rut: json['rut'] ?? '',
      nombre: json['nombre'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rut': rut,
      'nombre': nombre,
    };
  }
}
