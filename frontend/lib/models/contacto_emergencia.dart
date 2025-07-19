class ContactoEmergencia {
  final String id;
  final String nombre;
  final String telefono;
  final String? email;
  final DateTime fechaCreacion;

  ContactoEmergencia({
    required this.id,
    required this.nombre,
    required this.telefono,
    this.email,
    required this.fechaCreacion,
  });

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'telefono': telefono,
      'email': email,
      'fechaCreacion': fechaCreacion.toIso8601String(),
    };
  }

  // Crear desde JSON
  factory ContactoEmergencia.fromJson(Map<String, dynamic> json) {
    return ContactoEmergencia(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      telefono: json['telefono'] ?? '',
      email: json['email'],
      fechaCreacion: DateTime.parse(json['fechaCreacion'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Copiar con modificaciones
  ContactoEmergencia copyWith({
    String? id,
    String? nombre,
    String? telefono,
    String? email,
    DateTime? fechaCreacion,
  }) {
    return ContactoEmergencia(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  @override
  String toString() {
    return 'ContactoEmergencia{id: $id, nombre: $nombre, telefono: $telefono}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactoEmergencia &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
