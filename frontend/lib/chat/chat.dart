import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Importa SecureStorage
import '../widgets/navbar_con_sos_dinamico.dart';
import 'pagina_individual.dart'; // Cambiar a la versión WebSocket
import 'chat_grupal.dart'; // Importar chat grupal
import '../models/user_models.dart';
import '../models/chat_grupal_models.dart'; // Importar modelos de chat grupal
import '../models/viaje_chat_model.dart'; // Importar modelo de viaje chat
import '../services/amistad_service.dart'; // Importar el servicio de amistad
import '../services/chat_grupal_service.dart'; // Importar servicio de chat grupal

class Chat extends StatefulWidget {
  @override
  ChatState createState() => ChatState();
}

class ChatState extends State<Chat> with TickerProviderStateMixin {
  // --- TabController para las pestañas ---
  late TabController _tabController;

  // --- Variables de Estado para la UI ---
  List<User> amigosDisponibles = [];
  List<ViajeChat> viajesDisponibles = [];
  bool isLoading = true;
  String? errorMessage;
  int _selectedIndex = 3;

  // --- Variables para el token y RUT (ahora NO hardcodeadas) ---
  String? _jwtToken; // Será nulo hasta que se cargue
  String? _rutUsuarioAutenticado; // Será nulo hasta que se cargue

  // --- Variables para el chat grupal ---
  ChatGrupalInfo? _viajeActivo;

  // Instancia de FlutterSecureStorage
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    // Inicializar TabController
    _tabController = TabController(length: 2, vsync: this);
    
    // Primero carga el token y el RUT, luego carga los amigos
    _initChatScreen();
  }

  @override
  void dispose() {
    // Cancelar cualquier operación pendiente
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initChatScreen() async {
    await _loadAuthData(); // Carga el token y el RUT
    if (_jwtToken != null && _rutUsuarioAutenticado != null) {
      // Cargar amigos y viaje activo en paralelo
      await Future.wait([
        _cargarAmigosDisponibles(),
        _cargarViajeActivo(),
        _cargarViajesParaChat(),
      ]);
    } else {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error: No se pudo cargar el token o el RUT del usuario. Por favor, reinicia la sesión.';
        });
      }
      print('ERROR: Token o RUT nulo al iniciar ChatScreen.');
    }
  }

  // --- Nueva función para cargar el token y RUT desde SecureStorage ---
  Future<void> _loadAuthData() async {
    try {
      _jwtToken = await _storage.read(key: 'jwt_token');
      _rutUsuarioAutenticado = await _storage.read(key: 'user_rut');

      print('DEBUG: Token cargado del storage: ${_jwtToken != null ? _jwtToken!.substring(0, _jwtToken!.length > 10 ? 10 : _jwtToken!.length) : "Nulo"}...');
      print('DEBUG: RUT cargado del storage: $_rutUsuarioAutenticado');

    } catch (e) {
      print('ERROR: Error al cargar token/rut de SecureStorage: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Error al cargar datos de sesión: $e';
          isLoading = false;
        });
      }
    }
  }

  // --- Función para cargar el viaje activo ---
  Future<void> _cargarViajeActivo() async {
    try {
      // Usar directamente ChatGrupalService para evitar conflictos
      final viajeActivo = await ChatGrupalService.obtenerViajeActivo();
      
      if (mounted) {
        setState(() {
          _viajeActivo = viajeActivo;
        });
      }
      
      print('🚗 Viaje activo cargado: ${viajeActivo.estaActivo}');
      
    } catch (e) {
      print('ERROR: Error al cargar viaje activo: $e');
    }
  }

  // --- Función para cargar los viajes donde el usuario está confirmado ---
  Future<void> _cargarViajesParaChat() async {
    try {
      final viajes = await ChatGrupalService.obtenerMisViajesParaChat();
      
      if (mounted) {
        setState(() {
          viajesDisponibles = viajes;
        });
      }
      
      print('🚗📋 Viajes para chat cargados: ${viajes.length}');
      
    } catch (e) {
      print('ERROR: Error al cargar viajes para chat: $e');
    }
  }
  
  // --- Función para cargar SOLO los amigos desde el backend ---
  Future<void> _cargarAmigosDisponibles() async {
    // Asegurarse de que el token esté disponible antes de la petición
    if (_jwtToken == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'No hay token de autenticación disponible. Por favor, vuelve a iniciar sesión.';
        });
      }
      print('ERROR: _cargarAmigosDisponibles llamado sin token JWT.');
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      // Usar el servicio de amistad para obtener SOLO los amigos confirmados
      final Map<String, dynamic> resultado = await AmistadService.obtenerAmigos();
      
      print('DEBUG: Resultado completo del servicio: $resultado');
      
      if (resultado['success'] == true) {
        final List<dynamic> amigosJson = resultado['data'] ?? [];
        print('DEBUG: Datos de amigos recibidos: $amigosJson');
        
        final List<User> amigos = [];
        
        for (var item in amigosJson) {
          try {
            // El backend devuelve { amigo: userData, fechaAmistad: ... }
            // Necesitamos extraer solo la parte 'amigo'
            final amigoData = item['amigo'];
            print('DEBUG: Procesando amigo: $amigoData');
            
            if (amigoData != null) {
              final user = User.fromJson(amigoData);
              amigos.add(user);
              print('DEBUG: Usuario agregado: ${user.nombreCompleto}');
            } else {
              print('DEBUG: amigoData es null para item: $item');
            }
          } catch (e) {
            print('ERROR: Error al procesar amigo: $e, item: $item');
          }
        }
        
        print('DEBUG: Total de amigos obtenidos: ${amigos.length}');
        
        if (mounted) {
          setState(() {
            amigosDisponibles = amigos;
            isLoading = false;
          });
        }
      } else {
        print('DEBUG: Success no es true. Resultado: $resultado');
        if (mounted) {
          setState(() {
            errorMessage = resultado['message'] ?? 'Error al cargar amigos';
            isLoading = false;
          });
        }
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error al cargar amigos: $e';
          isLoading = false;
        });
      }
      print('ERROR: Excepción al intentar cargar amigos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fondo = const Color(0xFFF8F2EF);
    final Color principal = const Color(0xFF6B3B2D);
    final Color secundario = const Color(0xFF8D4F3A);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: secundario,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Personales'),
            Tab(icon: Icon(Icons.directions_car), text: 'Viajes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Chats Personales (contenido actual)
          _buildChatPersonalesTab(fondo, principal, secundario),
          // TAB 2: Chats de Viajes (nuevo)
          _buildChatViajesTab(fondo, principal, secundario),
        ],
      ),
      bottomNavigationBar: NavbarConSOSDinamico(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == _selectedIndex) return;

          if (mounted) {
            setState(() {
              _selectedIndex = index;
            });
          }

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
              // Ya estamos en chat, no hacer nada
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

  // --- Método para construir la pestaña de Chats Personales ---
  Widget _buildChatPersonalesTab(Color fondo, Color principal, Color secundario) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: isLoading
          ? Center(child: CircularProgressIndicator(color: principal))
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage!, style: TextStyle(color: Colors.red)),
                      ElevatedButton(
                        onPressed: _cargarAmigosDisponibles,
                        child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: principal),
                      )
                    ],
                  ),
                )
              : ListView(
                  children: [
                    const SizedBox(height: 4),
                    // Verificar si hay amigos
                    if (amigosDisponibles.isEmpty)
                      Card(
                        color: Colors.orange.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(Icons.people_outline, size: 48, color: Colors.orange.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'No tienes amigos para chatear',
                                style: TextStyle(
                                  color: principal,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ve a tu perfil para enviar solicitudes de amistad',
                                style: TextStyle(color: secundario),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => Navigator.pushNamed(context, '/perfil'),
                                style: ElevatedButton.styleFrom(backgroundColor: principal),
                                child: const Text('Ir a Perfil', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // Generar la lista de chats con amigos DINÁMICAMENTE desde los usuarios obtenidos
                      ...amigosDisponibles.map((user) {
                        return Card(
                          color: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: principal.withOpacity(0.8),
                              child: Text(user.nombreCompleto[0], style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(user.nombreCompleto, style: TextStyle(color: principal)),
                            subtitle: Text(user.email, style: TextStyle(color: secundario)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PaginaIndividualWebSocket(
                                    nombre: user.nombreCompleto,
                                    rutAmigo: user.rut,
                                    rutUsuarioAutenticado: _rutUsuarioAutenticado, // Ahora es opcional
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                  ],
                ),
    );
  }

  // --- Método para construir la pestaña de Chats de Viajes ---
  Widget _buildChatViajesTab(Color fondo, Color principal, Color secundario) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: isLoading
          ? Center(child: CircularProgressIndicator(color: principal))
          : ListView(
              children: [
                const SizedBox(height: 4),
                // Verificar si hay viajes
                if (viajesDisponibles.isEmpty)
                  Card(
                    color: Colors.blue.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.directions_car_outlined, size: 48, color: Colors.blue.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No tienes viajes para chatear',
                            style: TextStyle(
                              color: principal,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Únete a viajes como pasajero o crea uno como conductor',
                            style: TextStyle(color: secundario),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.pushNamed(context, '/publicar'),
                            style: ElevatedButton.styleFrom(backgroundColor: principal),
                            child: const Text('Crear Viaje', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Generar la lista de chats de viajes
                  ...viajesDisponibles.map((viaje) {
                    return Card(
                      color: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: principal.withOpacity(0.8),
                          child: Icon(
                            viaje.soyElConductor ? Icons.drive_eta : Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          viaje.infoTitulo,
                          style: TextStyle(color: principal, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              viaje.rutaCompleta,
                              style: TextStyle(color: secundario, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              viaje.infoSubtitulo,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Icon(Icons.chevron_right, color: secundario),
                        onTap: () {
                          // Navegar al chat grupal de este viaje específico
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatGrupalScreen(
                                idViaje: viaje.idViaje,
                                nombreViaje: viaje.rutaCompleta,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
              ],
            ),
    );
  }
}