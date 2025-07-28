import 'dart:convert';

// Modelos para el chat grupal
class ChatGrupalInfo {
  final String idViaje;
  final String? origen;
  final String? destino;
  final DateTime? fechaViaje;
  final String? horaViaje;
  final int cantidadPasajeros;
  final List<ParticipanteChat> participantes;
  final bool estaActivo;
  final bool usuarioEstaEnChat;
  final String? conductorRut;
  final String? conductorNombre;

  ChatGrupalInfo({
    required this.idViaje,
    this.origen,
    this.destino,
    this.fechaViaje,
    this.horaViaje,
    required this.cantidadPasajeros,
    required this.participantes,
    required this.estaActivo,
    required this.usuarioEstaEnChat,
    this.conductorRut,
    this.conductorNombre,
  });

  factory ChatGrupalInfo.fromJson(Map<String, dynamic> json) {
    // Extraer origen y destino que vienen como objetos
    String? origenNombre;
    String? destinoNombre;
    
    if (json['origen'] is Map<String, dynamic>) {
      origenNombre = json['origen']['nombre'];
    } else if (json['origen'] is String) {
      origenNombre = json['origen'];
    }
    
    if (json['destino'] is Map<String, dynamic>) {
      destinoNombre = json['destino']['nombre'];  
    } else if (json['destino'] is String) {
      destinoNombre = json['destino'];
    }
    
    // Extraer nombre del conductor si viene como objeto
    String? conductorNombre;
    if (json['conductor'] is Map<String, dynamic>) {
      conductorNombre = json['conductor']['nombre'];
    } else if (json['conductorNombre'] is String) {
      conductorNombre = json['conductorNombre'];
    }
    
    return ChatGrupalInfo(
      idViaje: json['_id'] ?? json['idViaje'] ?? '', // El backend usa '_id'
      origen: origenNombre,
      destino: destinoNombre,
      fechaViaje: json['fecha_ida'] != null ? DateTime.parse(json['fecha_ida']) : null, // El backend usa 'fecha_ida'
      horaViaje: json['fecha_ida'] != null 
        ? () {
            final fecha = DateTime.parse(json['fecha_ida']);
            return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
          }()
        : null,
      cantidadPasajeros: (json['pasajeros'] as List<dynamic>?)?.length ?? 0, // Contar pasajeros
      participantes: (json['participantes'] as List<dynamic>?)
          ?.map((p) => ParticipanteChat.fromJson(p))
          .toList() ?? [],
      estaActivo: json['estado'] == 'activo' || json['estado'] == 'en_progreso' || json['estado'] == 'confirmado', // Basado en estado
      usuarioEstaEnChat: json['usuarioEstaEnChat'] ?? false,
      conductorRut: json['usuario_rut'], // El backend usa 'usuario_rut' para el creador
      conductorNombre: conductorNombre,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idViaje': idViaje,
      'origen': origen,
      'destino': destino,
      'fechaViaje': fechaViaje?.toIso8601String(),
      'horaViaje': horaViaje,
      'cantidadPasajeros': cantidadPasajeros,
      'participantes': participantes.map((p) => p.toJson()).toList(),
      'estaActivo': estaActivo,
      'usuarioEstaEnChat': usuarioEstaEnChat,
      'conductorRut': conductorRut,
      'conductorNombre': conductorNombre,
    };
  }

  // Método para crear una instancia vacía (sin viaje activo)
  factory ChatGrupalInfo.empty() {
    return ChatGrupalInfo(
      idViaje: '',
      cantidadPasajeros: 0,
      participantes: [],
      estaActivo: false,
      usuarioEstaEnChat: false,
    );
  }

  // Método para verificar si hay viaje activo
  bool get hayViajeActivo => idViaje.isNotEmpty && estaActivo;
}

class ParticipanteChat {
  final String rut;
  final String nombre;
  final String? email;
  final String? avatar;
  final bool esConductor;
  final DateTime? fechaUnion;
  final bool estaConectado;

  ParticipanteChat({
    required this.rut,
    required this.nombre,
    this.email,
    this.avatar,
    required this.esConductor,
    this.fechaUnion,
    required this.estaConectado,
  });

  factory ParticipanteChat.fromJson(Map<String, dynamic> json) {
    return ParticipanteChat(
      rut: json['rut'] ?? '',
      nombre: json['nombre'] ?? '',
      email: json['email'],
      avatar: json['avatar'],
      esConductor: json['esConductor'] ?? false,
      fechaUnion: json['fechaUnion'] != null ? DateTime.parse(json['fechaUnion']) : null,
      estaConectado: json['estaConectado'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rut': rut,
      'nombre': nombre,
      'email': email,
      'avatar': avatar,
      'esConductor': esConductor,
      'fechaUnion': fechaUnion?.toIso8601String(),
      'estaConectado': estaConectado,
    };
  }

  // Getter para obtener iniciales del nombre
  String get iniciales {
    final nombres = nombre.split(' ');
    if (nombres.length >= 2) {
      return '${nombres[0][0]}${nombres[1][0]}'.toUpperCase();
    }
    return nombres[0][0].toUpperCase();
  }
}

class MensajeGrupal {
  final int id;
  final String contenido;
  final String emisorRut;
  final String emisorNombre;
  final DateTime fecha;
  final String idViaje;
  final bool editado;
  final bool eliminado;
  final String tipo;
  final DateTime? fechaEdicion;
  final String? editadoPor;
  final Map<String, dynamic>? locationData; // Para mensajes de ubicación

  MensajeGrupal({
    required this.id,
    required this.contenido,
    required this.emisorRut,
    required this.emisorNombre,
    required this.fecha,
    required this.idViaje,
    required this.editado,
    required this.eliminado,
    required this.tipo,
    this.fechaEdicion,
    this.editadoPor,
    this.locationData,
  });

  factory MensajeGrupal.fromJson(Map<String, dynamic> json) {
    final contenido = json['contenido'] ?? '';
    String tipoMensaje = json['tipo'] ?? 'grupal';
    Map<String, dynamic>? locationData;
    
    // Verificar si es un mensaje de ubicación
    try {
      print('🔍 Revisando contenido: $contenido');
      final parsedContent = jsonDecode(contenido);
      print('🔍 Contenido parseado: $parsedContent');
      if (parsedContent is Map<String, dynamic> && parsedContent['type'] == 'location') {
        print('✅ Detectado mensaje de ubicación');
        tipoMensaje = 'location';
        locationData = {
          'latitude': parsedContent['latitude'],
          'longitude': parsedContent['longitude'],
          'accuracy': parsedContent['accuracy'],
          'timestamp': parsedContent['timestamp'],
        };
      } else {
        print('❌ No es mensaje de ubicación - type: ${parsedContent is Map ? parsedContent['type'] : 'no es map'}');
      }
    } catch (e) {
      // No es JSON válido, es un mensaje normal
      print('❌ Error parseando JSON: $e');
    }
    
    return MensajeGrupal(
      id: json['id'] ?? 0,
      contenido: tipoMensaje == 'location' ? 'Ubicación compartida' : contenido,
      emisorRut: json['emisor'] ?? json['emisorRut'] ?? '',
      emisorNombre: json['emisorNombre'] ?? '',
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha']) : DateTime.now(),
      idViaje: json['idViajeMongo'] ?? json['idViaje'] ?? '',
      editado: json['editado'] ?? false,
      eliminado: json['eliminado'] ?? false,
      tipo: tipoMensaje,
      fechaEdicion: json['fechaEdicion'] != null ? DateTime.parse(json['fechaEdicion']) : null,
      editadoPor: json['editadoPor'],
      locationData: locationData,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'id': id,
      'contenido': contenido,
      'emisor': emisorRut,
      'emisorRut': emisorRut,
      'emisorNombre': emisorNombre,
      'fecha': fecha.toIso8601String(),
      'idViajeMongo': idViaje,
      'idViaje': idViaje,
      'editado': editado,
      'eliminado': eliminado,
      'tipo': tipo,
      'fechaEdicion': fechaEdicion?.toIso8601String(),
      'editadoPor': editadoPor,
    };
    
    if (locationData != null) {
      json['locationData'] = locationData;
    }
    
    return json;
  }

  // Getter para obtener iniciales del emisor
  String get emisorIniciales {
    final nombres = emisorNombre.split(' ');
    if (nombres.length >= 2) {
      return '${nombres[0][0]}${nombres[1][0]}'.toUpperCase();
    }
    return nombres[0][0].toUpperCase();
  }

  // Getter para obtener color basado en el RUT del emisor
  int get colorIndex {
    return emisorRut.hashCode % 6; // 6 colores diferentes
  }
}

class EventoChatGrupal {
  final String tipo;
  final String idViaje;
  final String? participante;
  final String? mensaje;
  final DateTime fecha;
  final Map<String, dynamic> datos;

  EventoChatGrupal({
    required this.tipo,
    required this.idViaje,
    this.participante,
    this.mensaje,
    required this.fecha,
    required this.datos,
  });

  factory EventoChatGrupal.fromJson(Map<String, dynamic> json) {
    return EventoChatGrupal(
      tipo: json['_eventType'] ?? json['tipo'] ?? '',
      idViaje: json['idViaje'] ?? '',
      participante: json['participante'] ?? json['nuevoParticipante'] ?? json['participanteSalio'],
      mensaje: json['mensaje'],
      fecha: DateTime.now(),
      datos: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo': tipo,
      'idViaje': idViaje,
      'participante': participante,
      'mensaje': mensaje,
      'fecha': fecha.toIso8601String(),
      'datos': datos,
    };
  }

  // Getters para tipos de eventos específicos
  bool get esParticipanteUnido => tipo == 'participant_joined';
  bool get esParticipanteSalio => tipo == 'participant_left';
  bool get esChatCreado => tipo == 'group_chat_created';
  bool get esChatFinalizado => tipo == 'group_chat_finished';
  bool get esAgregadoAlChat => tipo == 'added_to_group_chat';
  bool get esEliminadoDelChat => tipo == 'removed_from_group_chat';
}

class EstadoChatGrupal {
  final String idViaje;
  final List<String> participantes;
  final bool estaEnChat;
  final bool chatActivo;
  final DateTime ultimaActividad;

  EstadoChatGrupal({
    required this.idViaje,
    required this.participantes,
    required this.estaEnChat,
    required this.chatActivo,
    required this.ultimaActividad,
  });

  factory EstadoChatGrupal.fromJson(Map<String, dynamic> json) {
    return EstadoChatGrupal(
      idViaje: json['idViaje'] ?? '',
      participantes: List<String>.from(json['participantes'] ?? []),
      estaEnChat: json['estaEnChat'] ?? false,
      chatActivo: json['chatActivo'] ?? false,
      ultimaActividad: json['ultimaActividad'] != null 
          ? DateTime.parse(json['ultimaActividad'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idViaje': idViaje,
      'participantes': participantes,
      'estaEnChat': estaEnChat,
      'chatActivo': chatActivo,
      'ultimaActividad': ultimaActividad.toIso8601String(),
    };
  }
}
