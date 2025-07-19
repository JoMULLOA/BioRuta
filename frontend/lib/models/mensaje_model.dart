// lib/models/message_model.dart

class Message {
  final int? id;          // ID único del mensaje (para edición/eliminación)
  final String senderRut; // El RUT del que envió el mensaje
  final String text;      // El contenido del mensaje
  final DateTime timestamp; // Cuándo se envió el mensaje
  final bool isEdited;    // Si el mensaje fue editado
  final bool isDeleted;   // Si el mensaje fue eliminado

  Message({
    this.id,
    required this.senderRut,
    required this.text,
    required this.timestamp,
    this.isEdited = false,
    this.isDeleted = false,
  });

  // Crear copia del mensaje con cambios
  Message copyWith({
    int? id,
    String? senderRut,
    String? text,
    DateTime? timestamp,
    bool? isEdited,
    bool? isDeleted,
  }) {
    return Message(
      id: id ?? this.id,
      senderRut: senderRut ?? this.senderRut,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  // Crear desde JSON del backend
  factory Message.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 Factory fromJson iniciado con: $json');
      
      // Convertir id de string a int si es necesario
      int? messageId;
      if (json['id'] != null) {
        print('🔍 Procesando ID: ${json['id']} (tipo: ${json['id'].runtimeType})');
        messageId = json['id'] is String ? int.tryParse(json['id']) : json['id'];
        print('🔍 ID convertido: $messageId');
      }
      
      print('🔍 Procesando emisor: ${json['emisor']}');
      String senderRut = json['emisor'].toString();
      
      print('🔍 Procesando contenido: ${json['contenido']}');
      String text = json['contenido'].toString();
      
      print('🔍 Procesando fecha: ${json['fecha']}');
      DateTime timestamp = DateTime.parse(json['fecha']);
      
      print('🔍 Procesando editado: ${json['editado']}');
      bool isEdited = json['editado'] ?? false;
      
      print('🔍 Procesando eliminado: ${json['eliminado']}');
      bool isDeleted = json['eliminado'] ?? false;
      
      print('🔍 Creando objeto Message...');
      return Message(
        id: messageId,
        senderRut: senderRut,
        text: text,
        timestamp: timestamp,
        isEdited: isEdited,
        isDeleted: isDeleted,
      );
    } catch (e) {
      print('❌ ERROR en Message.fromJson: $e');
      print('❌ JSON que causó el error: $json');
      rethrow;
    }
  }
}