import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/amistad_service.dart';
import '../chat/pagina_individual.dart';

class AmigosScreen extends StatefulWidget {
  @override
  State<AmigosScreen> createState() => _AmigosScreenState();
}

class _AmigosScreenState extends State<AmigosScreen> {
  List<dynamic> _amigos = [];
  bool _isLoading = true;
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  String? _rutUsuarioAutenticado;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    // Cargar RUT del usuario autenticado
    _rutUsuarioAutenticado = await _storage.read(key: 'user_rut');
    // Cargar amigos
    _cargarAmigos();
  }

  Future<void> _cargarAmigos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final resultado = await AmistadService.obtenerAmigos();
      
      setState(() {
        _amigos = resultado['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar amigos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _eliminarAmigo(String rutAmigo, String nombreAmigo) async {
    // Mostrar diálogo de confirmación
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Eliminar Amigo',
            style: TextStyle(
              color: Color(0xFF854937),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '¿Estás seguro de que quieres eliminar a $nombreAmigo de tu lista de amigos?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      try {
        final resultado = await AmistadService.eliminarAmistad(rutAmigo);

        if (resultado['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['message']),
              backgroundColor: Color(0xFF854937),
              duration: Duration(seconds: 2),
            ),
          );

          // Recargar la lista
          _cargarAmigos();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _iniciarChat(Map<String, dynamic> amigo) async {
    // Verificar que tenemos el RUT del usuario autenticado
    if (_rutUsuarioAutenticado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: No se pudo obtener datos del usuario'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar mensaje de que se está iniciando el chat
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo chat con ${amigo['nombreCompleto']}...'),
        backgroundColor: Color(0xFF854937),
        duration: Duration(seconds: 1),
      ),
    );

    // Navegar al chat individual
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaginaIndividualWebSocket(
          nombre: amigo['nombreCompleto'] ?? 'Usuario',
          rutAmigo: amigo['rut'] ?? '',
          rutUsuarioAutenticado: _rutUsuarioAutenticado, // Ahora es opcional
        ),
      ),
    );

    // Después del chat individual, navegar a la pestaña Chat principal
    Navigator.pushReplacementNamed(context, '/chat');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Mis Amigos (${_amigos.length})'),
        backgroundColor: const Color(0xFF854937),
        foregroundColor: Colors.white,
        elevation: 0,
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
                    'Cargando amigos...',
                    style: TextStyle(
                      color: Color(0xFF854937),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _amigos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No tienes amigos aún',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Envía solicitudes de amistad para comenzar',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF854937),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add, size: 18),
                            SizedBox(width: 8),
                            Text('Agregar Amigos'),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarAmigos,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _amigos.length,
                    itemBuilder: (context, index) {
                      final amistad = _amigos[index];
                      final amigo = amistad['amigo'];
                      
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
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          leading: Container(
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
                          title: Text(
                            amigo['nombreCompleto'] ?? 'Usuario desconocido',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text(
                                'RUT: ${amigo['rut'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Amigos desde: ${_formatearFecha(amistad['fechaAmistad'])}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Text(
                                  '✓ Chat disponible',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (String choice) {
                              if (choice == 'chat') {
                                _iniciarChat(amigo);
                              } else if (choice == 'eliminar') {
                                _eliminarAmigo(amigo['rut'], amigo['nombreCompleto']);
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem<String>(
                                value: 'chat',
                                child: Row(
                                  children: [
                                    Icon(Icons.chat, color: Color(0xFF854937), size: 20),
                                    SizedBox(width: 8),
                                    Text('Iniciar Chat'),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'eliminar',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text('Eliminar Amigo'),
                                  ],
                                ),
                              ),
                            ],
                            icon: Icon(
                              Icons.more_vert,
                              color: Colors.grey[600],
                            ),
                          ),
                          onTap: () => _iniciarChat(amigo),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _amigos.isNotEmpty 
        ? FloatingActionButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/chat'),
            backgroundColor: Color(0xFF854937),
            foregroundColor: Colors.white,
            child: Icon(Icons.chat),
            tooltip: 'Ir al Chat',
          )
        : FloatingActionButton(
            onPressed: () => Navigator.pop(context),
            backgroundColor: Color(0xFF854937),
            foregroundColor: Colors.white,
            child: Icon(Icons.person_add),
            tooltip: 'Agregar Amigos',
          ),
    );
  }

  String _formatearFecha(String? fechaString) {
    if (fechaString == null) return 'Fecha desconocida';
    
    try {
      final fecha = DateTime.parse(fechaString);
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }
}
