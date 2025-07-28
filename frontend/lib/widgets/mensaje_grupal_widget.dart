import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_grupal_models.dart';
import '../services/chat_grupal_service.dart';
import 'location_message_widget.dart';

class MensajeGrupalWidget extends StatefulWidget {
  final MensajeGrupal mensaje;
  final bool isOwn;
  final Function(MensajeGrupal, String) onEdit;
  final Function(MensajeGrupal) onDelete;

  const MensajeGrupalWidget({
    Key? key,
    required this.mensaje,
    required this.isOwn,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  MensajeGrupalWidgetState createState() => MensajeGrupalWidgetState();
}

class MensajeGrupalWidgetState extends State<MensajeGrupalWidget> {
  bool isEditing = false;
  late TextEditingController _editController;
  late FocusNode _editFocusNode;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.mensaje.contenido);
    _editFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      isEditing = true;
    });
    
    // Enfocar el campo de edición
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode.requestFocus();
    });
  }

  void _cancelEditing() {
    setState(() {
      isEditing = false;
      _editController.text = widget.mensaje.contenido;
    });
  }

  void _saveEdit() {
    final nuevoContenido = _editController.text.trim();
    if (nuevoContenido.isNotEmpty && nuevoContenido != widget.mensaje.contenido) {
      widget.onEdit(widget.mensaje, nuevoContenido);
    }
    
    setState(() {
      isEditing = false;
    });
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Mensaje'),
        content: const Text('¿Estás seguro de que quieres eliminar este mensaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete(widget.mensaje);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.mensaje.contenido));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensaje copiado al portapapeles'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🔧 Renderizando mensaje: tipo=${widget.mensaje.tipo}, locationData=${widget.mensaje.locationData}');
    
    // Si es un mensaje de ubicación, usar el widget especializado
    if (widget.mensaje.tipo == 'location' && widget.mensaje.locationData != null) {
      print('✅ Usando LocationMessageWidget');
      return LocationMessageWidget(
        latitude: widget.mensaje.locationData!['latitude'],
        longitude: widget.mensaje.locationData!['longitude'],
        senderName: widget.isOwn ? 'Tú' : widget.mensaje.emisorNombre,
        timestamp: widget.mensaje.fecha,
        isOwnMessage: widget.isOwn,
      );
    }

    print('📝 Usando mensaje de texto normal');
    // Mensaje de texto normal
    // Obtener colores del participante
    final colorParticipante = Color(
      ChatGrupalService.obtenerColorParticipante(widget.mensaje.emisorRut),
    );
    final colorFondo = Color(
      ChatGrupalService.obtenerColorFondoParticipante(widget.mensaje.emisorRut),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: widget.isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!widget.isOwn) ...[
            // Avatar del participante
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorParticipante,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.mensaje.emisorNombre.isNotEmpty
                      ? widget.mensaje.emisorNombre[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          // Contenido del mensaje
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: GestureDetector(
                onLongPress: () => _showMessageOptions(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isOwn ? colorParticipante : colorFondo,
                    borderRadius: BorderRadius.circular(16),
                    border: widget.isOwn
                        ? null
                        : Border.all(
                            color: colorParticipante.withOpacity(0.3),
                            width: 1,
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre del emisor (solo si no es propio)
                      if (!widget.isOwn)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            widget.mensaje.emisorNombre,
                            style: TextStyle(
                              color: colorParticipante,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      
                      // Contenido del mensaje
                      if (isEditing)
                        TextField(
                          controller: _editController,
                          focusNode: _editFocusNode,
                          maxLines: null,
                          style: TextStyle(
                            color: widget.isOwn ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Escribe tu mensaje...',
                            hintStyle: TextStyle(
                              color: widget.isOwn 
                                  ? Colors.white70 
                                  : Colors.black54,
                            ),
                          ),
                          onSubmitted: (_) => _saveEdit(),
                        )
                      else
                        Text(
                          widget.mensaje.contenido,
                          style: TextStyle(
                            color: widget.isOwn ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      
                      const SizedBox(height: 4),
                      
                      // Información del mensaje
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Fecha
                          Text(
                            ChatGrupalService.formatearFecha(widget.mensaje.fecha),
                            style: TextStyle(
                              color: widget.isOwn 
                                  ? Colors.white70 
                                  : Colors.black54,
                              fontSize: 10,
                            ),
                          ),
                          
                          // Indicador de editado
                          if (widget.mensaje.editado) ...[
                            const SizedBox(width: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit,
                                  size: 12,
                                  color: widget.isOwn 
                                      ? Colors.white60 
                                      : Colors.black45,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'editado',
                                  style: TextStyle(
                                    color: widget.isOwn 
                                        ? Colors.white60 
                                        : Colors.black45,
                                    fontSize: 9,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
                          // Botones de edición (solo si está editando)
                          if (isEditing) ...[
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: _cancelEditing,
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: widget.isOwn 
                                        ? Colors.white70 
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: _saveEdit,
                                  child: Icon(
                                    Icons.check,
                                    size: 16,
                                    color: widget.isOwn 
                                        ? Colors.white70 
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          if (widget.isOwn) ...[
            const SizedBox(width: 8),
            // Avatar propio
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorParticipante,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.mensaje.emisorNombre.isNotEmpty
                      ? widget.mensaje.emisorNombre[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showMessageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Opción copiar
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiar'),
              onTap: () {
                Navigator.of(context).pop();
                _copyToClipboard();
              },
            ),
            
            // Opciones solo para mensajes propios
            if (widget.isOwn) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Editar'),
                onTap: () {
                  Navigator.of(context).pop();
                  _startEditing();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteDialog();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
