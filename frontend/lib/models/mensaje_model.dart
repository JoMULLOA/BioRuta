// lib/models/message_model.dart

class Message {
  final String senderRut; // El RUT del que envió el mensaje
  final String text;      // El contenido del mensaje
  final DateTime timestamp; // Cuándo se envió el mensaje (opcional, pero buena práctica)

  Message({
    required this.senderRut,
    required this.text,
    required this.timestamp,
  });

  // Si en el futuro recibes mensajes del backend en JSON, puedes añadir un fromJson
  // factory Message.fromJson(Map<String, dynamic> json) {
  //   return Message(
  //     senderRut: json['senderRut'],
  //     text: json['text'],
  //     timestamp: DateTime.parse(json['timestamp']),
  //   );
  // }
}