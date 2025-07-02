// lib/models/user_model.dart
class User {
  final String rut;
  final String nombreCompleto;
  final String email;
  final String rol;

  User({
    required this.rut,
    required this.nombreCompleto,
    required this.email,
    required this.rol,
  });

  // Factory constructor para crear una instancia de User desde un mapa JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      rut: json['rut'],
      nombreCompleto: json['nombreCompleto'],
      email: json['email'],
      rol: json['rol'],
    );
  }
}