import 'package:flutter/material.dart';
import '../widgets/navbar_con_sos_dinamico.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Para parsear JSON
import '../config/confGlobal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/amistad_service.dart'; // Importar servicio de amistad
import '../helpers/notificacion_helpers.dart'; // Importar helpers de notificación
import '../widgets/reportar_usuario_dialog.dart';
import '../models/reporte_model.dart';

class ranking extends StatefulWidget {
  @override
  State<ranking> createState() => _RankingState();
}

class _RankingState extends State<ranking> {
  int _selectedIndex = 4; // índice para Ranking
  List<dynamic> _rankingData = []; // Lista para almacenar los datos del ranking
  String? _currentUserEmail; // Email del usuario actual
  bool _isClasificaciones = false; // false = puntos, true = clasificaciones

  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchRanking();
  }

  // Cargar información del usuario actual
  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserEmail = prefs.getString('user_email');
    } catch (e) {
      print('Error al cargar usuario actual: $e');
    }
  }

  Future<void> _fetchRanking() async {
    try {
      final endpoint = _isClasificaciones ? '/ranking/clasificaciones' : '/ranking/';
      final response = await http.get(Uri.parse('${confGlobal.baseUrl}$endpoint'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body); // Parsear el JSON
        setState(() {
          _rankingData = data['ranking']; // Acceder a la clave 'ranking'
          
          if (_isClasificaciones) {
            // Ordenar por clasificación descendente
            _rankingData.sort((a, b) {
              final aClasif = a['clasificacion'] ?? 0.0;
              final bClasif = b['clasificacion'] ?? 0.0;
              if (aClasif == 0.0) return 1; // Mover usuarios con clasificación 0 al final
              if (bClasif == 0.0) return -1;
              return bClasif.compareTo(aClasif);
            });
          } else {
            // Ordenar por puntuación descendente
            _rankingData.sort((a, b) {
              if (a['puntuacion'] == 0) return 1; // Mover usuarios con puntuación 0 al final
              if (b['puntuacion'] == 0) return -1;
              return b['puntuacion'].compareTo(a['puntuacion']); // Orden descendente
            });
          }
        });
      } else {
        setState(() {
          _rankingData = []; // Vaciar la lista en caso de error
        });
      }
    } catch (e) {
      setState(() {
        _rankingData = []; // Vaciar la lista en caso de error
      });
    }
  }

  // Cambiar entre puntos y clasificaciones
  void _toggleRankingType() {
    setState(() {
      _isClasificaciones = !_isClasificaciones;
    });
    _fetchRanking();
  }

  final Color fondo = const Color(0xFFF8F2EF);
  final Color principal = const Color(0xFF6B3B2D);
  final Color secundario = const Color(0xFF8D4F3A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Ranking'),
        backgroundColor: secundario,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isClasificaciones ? 'Top Calificaciones' : 'Top Usuarios',
              style: TextStyle(color: principal, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Botones para cambiar entre puntos y clasificaciones
            Container(
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_isClasificaciones) _toggleRankingType();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isClasificaciones ? principal : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.stars,
                              color: !_isClasificaciones ? Colors.white : secundario,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Puntos',
                              style: TextStyle(
                                color: !_isClasificaciones ? Colors.white : secundario,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!_isClasificaciones) _toggleRankingType();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isClasificaciones ? principal : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.grade,
                              color: _isClasificaciones ? Colors.white : secundario,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Calificaciones',
                              style: TextStyle(
                                color: _isClasificaciones ? Colors.white : secundario,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: _rankingData.length,
                itemBuilder: (context, index) {
                  final user = _rankingData[index];
                  final isCurrentUser = user['email'] == _currentUserEmail;
                  
                  if (_isClasificaciones) {
                    return _buildRankingItem(
                      user, 
                      user['clasificacion']?.toDouble() ?? 0.0, 
                      index + 1,
                      isCurrentUser,
                      true, // Es clasificación
                    );
                  } else {
                    return _buildRankingItem(
                      user, 
                      user['puntuacion']?.toDouble() ?? 0.0, 
                      index + 1,
                      isCurrentUser,
                      false, // Es puntuación
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavbarConSOSDinamico(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == _selectedIndex) return;

          setState(() {
            _selectedIndex = index;
          });

          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/mis-viajes');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/mapa');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/publicar');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/chat');
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/ranking');
              break;
            case 5:
              Navigator.pushReplacementNamed(context, '/perfil');
              break;
          }
        },
      ),
    );
  }

  Widget _buildRankingItem(Map<String, dynamic> userData, double valor, int posicion, bool isCurrentUser, bool isClasificacion) {
    final String nombre = userData['nombreCompleto'] ?? '';
    final String rutUsuario = userData['rut'] ?? '';
    
    IconData icono;
    Color color;
    Color? marcoColor;

    // Definir colores solo para el top 3, el resto será neutro
    switch (posicion) {
      case 1:
        icono = Icons.emoji_events;
        color = Colors.amber;
        marcoColor = Colors.amber; // Marco dorado para el primer lugar
        break;
      case 2:
        icono = Icons.emoji_events;
        color = Colors.grey;
        marcoColor = Colors.grey[400]; // Marco plateado para el segundo lugar
        break;
      case 3:
        icono = Icons.emoji_events;
        color = Color(0xFF8B4513); // Color café para el ícono
        marcoColor = Color(0xFF8B4513); // Marco café (SaddleBrown) para el tercer lugar
        break;
      default:
        // Para usuarios fuera del podio, usar colores neutros
        icono = isClasificacion ? Icons.grade : Icons.star_border;
        color = Colors.grey[400]!; // Color gris neutro
        marcoColor = null; // Sin marco especial para otros lugares
        break;
    }

    // Formatear el valor según el tipo
    String valorTexto;
    if (isClasificacion) {
      valorTexto = valor > 0 ? valor.toStringAsFixed(1) : '0.0';
    } else {
      valorTexto = valor.toInt().toString();
    }

    return Container(
      // Hacer el contenedor más grande si es el usuario actual
      margin: EdgeInsets.symmetric(
        vertical: isCurrentUser ? 8.0 : 6.0,
        horizontal: isCurrentUser ? 8.0 : 0.0,
      ),
      child: Transform.scale(
        scale: isCurrentUser ? 1.05 : 1.0, // Escalar ligeramente si es el usuario actual
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: _buildBorder(isCurrentUser, marcoColor, posicion),
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          elevation: _getElevation(isCurrentUser, posicion),
          color: isCurrentUser 
            ? fondo.withOpacity(0.9) 
            : Colors.white,
          child: Container(
            decoration: _buildContainerDecoration(isCurrentUser, marcoColor, posicion),
            child: ListTile(
              onTap: isCurrentUser ? null : () => _mostrarDialogoSolicitudAmistad(context, nombre, userData),
              onLongPress: isCurrentUser ? null : () => _mostrarDialogoReporte(context, rutUsuario, nombre),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isCurrentUser ? 20.0 : 16.0,
                vertical: isCurrentUser ? 8.0 : 4.0,
              ),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: isCurrentUser ? 24.0 : 20.0, // Avatar más grande para usuario actual
                    backgroundColor: color.withOpacity(posicion <= 3 ? 0.8 : 0.3), // Menos opacidad fuera del podio
                    child: Icon(
                      icono, 
                      color: posicion <= 3 ? Colors.white : Colors.grey[600], // Color más neutro fuera del podio
                      size: isCurrentUser ? 28.0 : 24.0, // Ícono más grande para usuario actual
                    ),
                  ),
                  if (isCurrentUser)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: principal,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 14, // Ícono de persona un poco más grande
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                nombre, 
                style: TextStyle(
                  color: posicion <= 3 ? principal : Colors.grey[700], // Color más neutro fuera del podio
                  fontWeight: isCurrentUser ? FontWeight.w900 : (posicion <= 3 ? FontWeight.bold : FontWeight.w500),
                  fontSize: isCurrentUser ? 18 : 14, // Texto más grande para usuario actual
                ),
              ),
              subtitle: Text(
                isClasificacion ? 'Calificación: $valorTexto ⭐' : 'Puntos: $valorTexto', 
                style: TextStyle(
                  color: posicion <= 3 ? secundario : Colors.grey[500], // Color más neutro fuera del podio
                  fontWeight: isCurrentUser ? FontWeight.w600 : FontWeight.normal,
                  fontSize: isCurrentUser ? 15 : 12, // Subtítulo más grande para usuario actual
                ),
              ),
              trailing: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCurrentUser ? 12 : 8, 
                  vertical: isCurrentUser ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  color: _getTrailingColor(isCurrentUser, marcoColor, posicion),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$posicion', 
                  style: TextStyle(
                    color: _getTrailingTextColor(isCurrentUser, marcoColor, posicion), 
                    fontSize: isCurrentUser ? 18 : 16, // Posición más grande para usuario actual
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      )
      )
      ;
  }

  // Función para determinar el borde
  BorderSide _buildBorder(bool isCurrentUser, Color? marcoColor, int posicion) {
    if (posicion <= 3 && marcoColor != null) {
      // Marco especial solo para top 3
      return BorderSide(color: marcoColor, width: 3);
    } else if (isCurrentUser && posicion <= 3) {
      // Marco para usuario actual solo si está en el podio
      return BorderSide(color: principal, width: 3);
    } else {
      // Sin marco para usuarios fuera del podio, incluso si es el usuario actual
      return BorderSide.none;
    }
  }

  // Función para determinar la elevación
  double _getElevation(bool isCurrentUser, int posicion) {
    if (posicion <= 3) {
      // Elevación especial para top 3
      return 6.0;
    } else if (isCurrentUser) {
      // Elevación para usuario actual
      return 8.0;
    } else {
      // Elevación mínima para usuarios fuera del podio
      return 1.0;
    }
  }

  // Función para determinar la decoración del contenedor
  BoxDecoration? _buildContainerDecoration(bool isCurrentUser, Color? marcoColor, int posicion) {
    if (marcoColor != null && posicion <= 3) {
      // Gradiente especial solo para top 3
      return BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            marcoColor.withOpacity(0.1),
            Colors.white.withOpacity(0.8),
          ],
        ),
      );
    } else if (isCurrentUser && posicion <= 3) {
      // Gradiente para usuario actual solo si está en el podio
      return BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            principal.withOpacity(0.1),
            fondo.withOpacity(0.5),
          ],
        ),
      );
    }
    // Sin decoración especial para usuarios fuera del podio (fondo blanco simple)
    return null;
  }

  // Función para determinar el color de fondo del trailing
  Color _getTrailingColor(bool isCurrentUser, Color? marcoColor, int posicion) {
    if (marcoColor != null && posicion <= 3) {
      return marcoColor;
    } else if (isCurrentUser && posicion <= 3) {
      // Solo usar color principal si el usuario actual está en el podio
      return principal;
    } else {
      // Color transparente para usuarios fuera del podio, incluso si es el usuario actual
      return Colors.transparent;
    }
  }

  // Función para determinar el color del texto del trailing
  Color _getTrailingTextColor(bool isCurrentUser, Color? marcoColor, int posicion) {
    if (marcoColor != null && posicion <= 3) {
      return Colors.white;
    } else if (isCurrentUser && posicion <= 3) {
      // Solo usar texto blanco si el usuario actual está en el podio
      return Colors.white;
    } else {
      // Color gris para usuarios fuera del podio, incluso si es el usuario actual
      return Colors.grey[600]!;
    }
  }

  // Función para mostrar el diálogo de solicitud de amistad
  void _mostrarDialogoSolicitudAmistad(BuildContext context, String nombreUsuario, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.person_add, color: principal, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enviar solicitud',
                  style: TextStyle(
                    color: principal,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: fondo.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: secundario,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombreUsuario,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: principal,
                            ),
                          ),
                          Text(
                            'Posición #${_rankingData.indexOf(userData) + 1}',
                            style: TextStyle(
                              color: secundario,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                '¿Quieres enviar una solicitud de amistad a $nombreUsuario?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _enviarSolicitudAmistad(context, userData['rut'], nombreUsuario);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: principal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.send, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Enviar',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Función para mostrar el diálogo de reporte
  void _mostrarDialogoReporte(BuildContext context, String rutUsuario, String nombreUsuario) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReportarUsuarioDialog(
          usuarioReportado: rutUsuario,
          nombreUsuario: nombreUsuario,
          tipoReporte: TipoReporte.ranking,
        );
      },
    );
  }

  // Función para enviar la solicitud de amistad
  Future<void> _enviarSolicitudAmistad(BuildContext context, String rutReceptor, String nombreUsuario) async {
    try {
      // Enviar solicitud directamente sin indicador de carga
      final resultado = await AmistadService.enviarSolicitudAmistad(
        rutReceptor: rutReceptor,
        mensaje: "¿Puedo ser tu amigo?",
      );

      if (resultado['success']) {
        // Mostrar notificación de éxito
        NotificacionHelpers.mostrarSolicitudEnviada(context, nombreUsuario);
      } else {
        // Verificar si el mensaje es sobre que ya son amigos
        final mensaje = resultado['message'] ?? '';
        if (mensaje.toLowerCase().contains('ya son amigos') || 
            mensaje.toLowerCase().contains('already friends') ||
            mensaje.toLowerCase().contains('amistad ya existe')) {
          // Mostrar notificación bonita específica para ya son amigos
          NotificacionHelpers.mostrarYaSonAmigos(context, nombreUsuario);
        } else {
          // Mostrar error para otros casos
          NotificacionHelpers.mostrarError(
            context,
            titulo: 'Error al enviar solicitud',
            mensaje: mensaje.isNotEmpty ? mensaje : 'No se pudo enviar la solicitud',
          );
        }
      }
    } catch (e) {
      print('Error al enviar solicitud: $e');
      
      // Mostrar error de conexión
      NotificacionHelpers.mostrarError(
        context,
        titulo: 'Error de conexión',
        mensaje: 'No se pudo conectar con el servidor',
      );
    }
  }
}
