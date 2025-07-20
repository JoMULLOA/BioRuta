import 'package:flutter/material.dart';
import '../models/reporte_model.dart';
import '../services/reporte_service.dart';

class ReportarUsuarioDialog extends StatefulWidget {
  final String usuarioReportado;
  final String nombreUsuario;
  final TipoReporte tipoReporte;

  const ReportarUsuarioDialog({
    Key? key,
    required this.usuarioReportado,
    required this.nombreUsuario,
    required this.tipoReporte,
  }) : super(key: key);

  @override
  _ReportarUsuarioDialogState createState() => _ReportarUsuarioDialogState();
}

class _ReportarUsuarioDialogState extends State<ReportarUsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  MotivoReporte? _motivoSeleccionado;
  bool _isLoading = false;

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _enviarReporte() async {
    if (!_formKey.currentState!.validate() || _motivoSeleccionado == null) {
      _showMessage(
        'Por favor selecciona un motivo para el reporte',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final resultado = await ReporteService.crearReporte(
        usuarioReportado: widget.usuarioReportado,
        tipoReporte: widget.tipoReporte,
        motivo: _motivoSeleccionado!,
        descripcion: _descripcionController.text.trim().isNotEmpty
            ? _descripcionController.text.trim()
            : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (resultado['success']) {
          _showMessage(resultado['message'] ?? 'Reporte enviado exitosamente');
          Navigator.of(context).pop(true);
        } else {
          _showMessage(
            resultado['message'] ?? 'Error al enviar el reporte',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showMessage(
          'Error inesperado. Intenta nuevamente.',
          isError: true,
        );
      }
    }
  }

  Widget _buildLoadingWidget() {
    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF8D4F3A),
          ),
          SizedBox(height: 16),
          Text(
            'Enviando reporte...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.report,
            color: Colors.red,
            size: 28,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reportar Usuario',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.nombreUsuario,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: _isLoading
          ? _buildLoadingWidget()
          : SingleChildScrollView(
              child: SizedBox(
                width: double.maxFinite,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Información del contexto
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF8D4F3A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Color(0xFF8D4F3A).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getTipoReporteIcon(widget.tipoReporte),
                            color: Color(0xFF8D4F3A),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Reportando desde: ${widget.tipoReporte.displayName}',
                            style: TextStyle(
                              color: Color(0xFF8D4F3A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 16),

                    // Selector de motivo
                    Text(
                      'Motivo del reporte *',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<MotivoReporte>(
                          value: _motivoSeleccionado,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: InputBorder.none,
                          ),
                          hint: Text('Selecciona un motivo'),
                          items: MotivoReporte.values.map((motivo) {
                            return DropdownMenuItem<MotivoReporte>(
                              value: motivo,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getMotivoIcon(motivo),
                                    color: Colors.grey[600],
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      motivo.displayName,
                                      style: TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (MotivoReporte? value) {
                            setState(() {
                              _motivoSeleccionado = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Por favor selecciona un motivo';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Campo de descripción
                    Text(
                      'Descripción adicional (opcional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    
                    TextFormField(
                      controller: _descripcionController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'Describe brevemente la situación...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Color(0xFF8D4F3A),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 8),

                    // Información adicional
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tu reporte será revisado por nuestro equipo de moderación. Los reportes falsos pueden resultar en restricciones en tu cuenta.',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
      actions: _isLoading
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: _enviarReporte,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Enviar'),
              ),
            ],
    );
  }

  IconData _getTipoReporteIcon(TipoReporte tipo) {
    switch (tipo) {
      case TipoReporte.ranking:
        return Icons.leaderboard;
      case TipoReporte.chatIndividual:
        return Icons.person;
      case TipoReporte.chatGrupal:
        return Icons.group;
    }
  }

  IconData _getMotivoIcon(MotivoReporte motivo) {
    switch (motivo) {
      case MotivoReporte.comportamientoInapropiado:
        return Icons.warning;
      case MotivoReporte.lenguajeOfensivo:
        return Icons.record_voice_over;
      case MotivoReporte.spam:
        return Icons.block;
      case MotivoReporte.contenidoInadecuado:
        return Icons.visibility_off;
      case MotivoReporte.acoso:
        return Icons.person_off;
      case MotivoReporte.fraude:
        return Icons.security;
      case MotivoReporte.suplantacion:
        return Icons.person_pin_circle;
      case MotivoReporte.otro:
        return Icons.more_horiz;
    }
  }
}
