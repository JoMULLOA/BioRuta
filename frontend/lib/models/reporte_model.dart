import 'package:flutter/material.dart';

class Reporte {
  final int? id;
  final String usuarioReportante;
  final String usuarioReportado;
  final TipoReporte tipoReporte;
  final MotivoReporte motivo;
  final String? descripcion;
  final EstadoReporte estado;
  final DateTime fechaCreacion;
  final DateTime? fechaRevision;
  final String? adminRevisor;
  final String? comentarioAdmin;
  final bool notificacionEnviada;

  Reporte({
    this.id,
    required this.usuarioReportante,
    required this.usuarioReportado,
    required this.tipoReporte,
    required this.motivo,
    this.descripcion,
    required this.estado,
    required this.fechaCreacion,
    this.fechaRevision,
    this.adminRevisor,
    this.comentarioAdmin,
    this.notificacionEnviada = false,
  });

  factory Reporte.fromJson(Map<String, dynamic> json) {
    try {
      return Reporte(
        id: json['id'],
        usuarioReportante: json['usuarioReportante'] ?? '',
        usuarioReportado: json['usuarioReportado'] ?? '',
        tipoReporte: TipoReporte.values.firstWhere(
          (e) => e.toString().split('.').last == json['tipoReporte'],
          orElse: () => TipoReporte.ranking,
        ),
        motivo: MotivoReporte.values.firstWhere(
          (e) => e.toString().split('.').last == json['motivo'],
          orElse: () => MotivoReporte.otro,
        ),
        descripcion: json['descripcion'],
        estado: EstadoReporte.values.firstWhere(
          (e) => e.toString().split('.').last == json['estado'],
          orElse: () => EstadoReporte.pendiente,
        ),
        fechaCreacion: DateTime.tryParse(json['fechaCreacion']?.toString() ?? '') ?? DateTime.now(),
        fechaRevision: json['fechaRevision'] != null 
            ? DateTime.tryParse(json['fechaRevision'].toString())
            : null,
        adminRevisor: json['adminRevisor'],
        comentarioAdmin: json['comentarioAdmin'],
        notificacionEnviada: json['notificacionEnviada'] ?? false,
      );
    } catch (e) {
      print('Error al parsear reporte desde JSON: $e');
      print('JSON recibido: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuarioReportante': usuarioReportante,
      'usuarioReportado': usuarioReportado,
      'tipoReporte': tipoReporte.toString().split('.').last,
      'motivo': motivo.toString().split('.').last,
      'descripcion': descripcion,
      'estado': estado.toString().split('.').last,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fechaRevision': fechaRevision?.toIso8601String(),
      'adminRevisor': adminRevisor,
      'comentarioAdmin': comentarioAdmin,
      'notificacionEnviada': notificacionEnviada,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'usuarioReportado': usuarioReportado,
      'tipoReporte': tipoReporte.toString().split('.').last,
      'motivo': motivo.toString().split('.').last,
      'descripcion': descripcion,
    };
  }
}

enum TipoReporte {
  ranking,
  chatIndividual,
  chatGrupal,
}

enum MotivoReporte {
  comportamientoInapropiado,
  lenguajeOfensivo,
  spam,
  contenidoInadecuado,
  acoso,
  fraude,
  suplantacion,
  otro,
}

enum EstadoReporte {
  pendiente,
  revisado,
  aceptado,
  rechazado,
}

extension TipoReporteExtension on TipoReporte {
  String get displayName {
    switch (this) {
      case TipoReporte.ranking:
        return 'Ranking';
      case TipoReporte.chatIndividual:
        return 'Chat Individual';
      case TipoReporte.chatGrupal:
        return 'Chat Grupal';
    }
  }
}

extension MotivoReporteExtension on MotivoReporte {
  String get displayName {
    switch (this) {
      case MotivoReporte.comportamientoInapropiado:
        return 'Comportamiento Inapropiado';
      case MotivoReporte.lenguajeOfensivo:
        return 'Lenguaje Ofensivo';
      case MotivoReporte.spam:
        return 'Spam';
      case MotivoReporte.contenidoInadecuado:
        return 'Contenido Inadecuado';
      case MotivoReporte.acoso:
        return 'Acoso';
      case MotivoReporte.fraude:
        return 'Fraude';
      case MotivoReporte.suplantacion:
        return 'Suplantación';
      case MotivoReporte.otro:
        return 'Otro';
    }
  }
}

extension EstadoReporteExtension on EstadoReporte {
  String get displayName {
    switch (this) {
      case EstadoReporte.pendiente:
        return 'Pendiente';
      case EstadoReporte.revisado:
        return 'Revisado';
      case EstadoReporte.aceptado:
        return 'Procesado';
      case EstadoReporte.rechazado:
        return 'Descartado';
    }
  }
  
  Color get color {
    switch (this) {
      case EstadoReporte.pendiente:
        return Colors.orange;
      case EstadoReporte.revisado:
        return Colors.blue;
      case EstadoReporte.aceptado:
        return Colors.red; // Procesado - se tomaron medidas
      case EstadoReporte.rechazado:
        return Colors.grey; // Descartado - sin fundamento
    }
  }
}
