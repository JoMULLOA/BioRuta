import 'package:flutter/material.dart';
import '../services/amistad_service.dart';

class NotificacionesScreen extends StatefulWidget {
  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  List<dynamic> _solicitudesPendientes = [];
  bool _isLoading = true;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _cargarSolicitudesPendientes();
  }

  Future<void> _cargarSolicitudesPendientes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final resultado = await AmistadService.obtenerSolicitudesPendientes();
      
      setState(() {
        _solicitudesPendientes = resultado['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar solicitudes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _responderSolicitud(int idSolicitud, String respuesta, String nombreEmisor) async {
    setState(() {
      _isResponding = true;
    });

    try {
      final resultado = await AmistadService.responderSolicitudAmistad(
        idSolicitud: idSolicitud,
        respuesta: respuesta,
      );

      setState(() {
        _isResponding = false;
      });

      if (resultado['success']) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado['message']),
            backgroundColor: respuesta == 'aceptada' ? Colors.green : Color(0xFF854937),
            duration: Duration(seconds: 3),
          ),
        );

        // Recargar la lista
        _cargarSolicitudesPendientes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${resultado['message']}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isResponding = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarDialogoConfirmacion(int idSolicitud, String respuesta, String nombreEmisor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            respuesta == 'aceptada' ? 'Aceptar Solicitud' : 'Rechazar Solicitud',
            style: TextStyle(
              color: Color(0xFF854937),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            respuesta == 'aceptada' 
                ? '¿Estás seguro de que quieres aceptar la solicitud de amistad de $nombreEmisor?'
                : '¿Estás seguro de que quieres rechazar la solicitud de amistad de $nombreEmisor?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _responderSolicitud(idSolicitud, respuesta, nombreEmisor);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: respuesta == 'aceptada' ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(respuesta == 'aceptada' ? 'Aceptar' : 'Rechazar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Solicitudes de Amistad'),
        backgroundColor: const Color(0xFF854937),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarSolicitudesPendientes,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF854937)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cargando notificaciones...',
                    style: TextStyle(
                      color: Color(0xFF854937),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _solicitudesPendientes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No tienes solicitudes pendientes',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Las solicitudes de amistad aparecerán aquí',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarSolicitudesPendientes,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _solicitudesPendientes.length,
                    itemBuilder: (context, index) {
                      final solicitud = _solicitudesPendientes[index];
                      final emisor = solicitud['emisor'];
                      
                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: Color(0xFF854937).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header con avatar y nombre
                              Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF854937).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: Color(0xFF854937),
                                      size: 25,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Solicitud de Amistad',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF854937),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          emisor['nombreCompleto'] ?? 'Usuario desconocido',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Pendiente',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 12),
                              
                              // Mensaje
                              if (solicitud['mensaje'] != null && solicitud['mensaje'].isNotEmpty) ...[
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF8F2EF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    solicitud['mensaje'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12),
                              ],
                              
                              // Fecha
                              Text(
                                'Recibida: ${_formatearFecha(solicitud['fechaEnvio'])}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              
                              SizedBox(height: 16),
                              
                              // Botones de acción
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isResponding 
                                          ? null 
                                          : () => _mostrarDialogoConfirmacion(
                                              solicitud['id'], 
                                              'rechazada', 
                                              emisor['nombreCompleto']
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isResponding ? Colors.grey[300] : Colors.red,
                                        foregroundColor: _isResponding ? Colors.grey[500] : Colors.white,
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.close, size: 18),
                                          SizedBox(width: 4),
                                          Text('Rechazar'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isResponding 
                                          ? null 
                                          : () => _mostrarDialogoConfirmacion(
                                              solicitud['id'], 
                                              'aceptada', 
                                              emisor['nombreCompleto']
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isResponding ? Colors.grey[300] : Colors.green,
                                        foregroundColor: _isResponding ? Colors.grey[500] : Colors.white,
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check, size: 18),
                                          SizedBox(width: 4),
                                          Text('Aceptar'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatearFecha(String? fechaString) {
    if (fechaString == null) return 'Fecha desconocida';
    
    try {
      final fecha = DateTime.parse(fechaString);
      final ahora = DateTime.now();
      final diferencia = ahora.difference(fecha);

      if (diferencia.inMinutes < 1) {
        return 'Hace un momento';
      } else if (diferencia.inHours < 1) {
        return 'Hace ${diferencia.inMinutes} minutos';
      } else if (diferencia.inDays < 1) {
        return 'Hace ${diferencia.inHours} horas';
      } else if (diferencia.inDays < 7) {
        return 'Hace ${diferencia.inDays} días';
      } else {
        return '${fecha.day}/${fecha.month}/${fecha.year}';
      }
    } catch (e) {
      return 'Fecha inválida';
    }
  }
}
