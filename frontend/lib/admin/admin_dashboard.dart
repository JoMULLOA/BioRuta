import 'package:flutter/material.dart';
import '../widgets/admin_navbar.dart';
import 'admin_profile.dart';
import 'admin_stats.dart';
import '../services/user_service.dart';
import '../services/peticion_supervision_service.dart';
import '../chat/pagina_individual.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0; // Dashboard es la primera pestaña
  
  // Variables para estadísticas
  int _totalUsuarios = 0;
  int _viajesHoy = 0;
  int _usuariosActivos = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    // Aquí puedes cargar las estadísticas desde el backend
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulando carga de datos (reemplaza con llamadas reales al backend)
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _totalUsuarios = 150;
        _viajesHoy = 25;
        _usuariosActivos = 45;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error cargando datos del dashboard: $e');
    }
  }

  Widget _getCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardHome();
      case 1:
        return _buildStatsPage();
      case 2:
        return _buildUsersPage();
      case 3:
        return _buildSupportPage();
      case 4:
        return const AdminProfile();
      default:
        return _buildDashboardHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getCurrentPage(),
      bottomNavigationBar: AdminNavbar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildDashboardHome() {
    final Color fondo = Color(0xFFF8F2EF);
    final Color primario = Color(0xFF6B3B2D);
    final Color secundario = Color(0xFF8D4F3A);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: primario,
        elevation: 0,
        title: const Text(
          'Dashboard Administrativo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // Quitar flecha de volver
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primario),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: primario,
              backgroundColor: fondo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bienvenida
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [primario, secundario],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings, 
                                   color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              const Text(
                                'Panel de Administración',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Gestiona usuarios, estadísticas y el sistema completo',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Estadísticas Principales
                    const Text(
                      'Estadísticas Generales',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B3B2D),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grid de estadísticas
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard(
                          'Total Usuarios',
                          _totalUsuarios.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'Viajes Hoy',
                          _viajesHoy.toString(),
                          Icons.directions_car,
                          Colors.green,
                        ),
                        _buildStatCard(
                          'Usuarios Activos',
                          _usuariosActivos.toString(),
                          Icons.people_alt,
                          Colors.orange,
                        ),
                        _buildStatCard(
                          'Sistema',
                          'Activo',
                          Icons.check_circle,
                          Colors.teal,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Acciones Rápidas
                    const Text(
                      'Acciones Rápidas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B3B2D),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botones de acciones
                    Column(
                      children: [
                        _buildActionButton(
                          'Estadísticas Detalladas',
                          'Ver reportes y métricas completas',
                          Icons.analytics,
                          secundario,
                          () {
                            setState(() {
                              _selectedIndex = 1; // Navegar a estadísticas
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsPage() {
    return const AdminStats();
  }

  Widget _buildUsersPage() {
    final Color fondo = Color(0xFFF8F2EF);
    final Color primario = Color(0xFF6B3B2D);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: primario,
        elevation: 0,
        title: const Text(
          'Gestión de Usuarios',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                // Esto forzará una recarga de los datos
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Usuario>>(
        future: UserService.obtenerTodosLosUsuarios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primario),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cargando usuarios...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al cargar usuarios',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        // Reintentar carga
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primario,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final usuarios = snapshot.data ?? [];

          if (usuarios.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay usuarios registrados',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Los usuarios aparecerán aquí cuando se registren',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Resumen de estadísticas
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      'Total',
                      usuarios.length.toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                    _buildStatColumn(
                      'Activos',
                      usuarios.where((u) => u.esActivo).length.toString(),
                      Icons.people_alt,
                      Colors.green,
                    ),
                    _buildStatColumn(
                      'Admins',
                      usuarios.where((u) => u.rol == 'administrador').length.toString(),
                      Icons.admin_panel_settings,
                      Colors.orange,
                    ),
                    _buildStatColumn(
                      'Usuarios',
                      usuarios.where((u) => u.rol == 'usuario').length.toString(),
                      Icons.person,
                      Colors.purple,
                    ),
                  ],
                ),
              ),

              // Lista de usuarios
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: usuarios.length,
                  itemBuilder: (context, index) {
                    final usuario = usuarios[index];
                    return _buildUserCard(usuario);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSupportPage() {
    final Color fondo = Color(0xFFF8F2EF);
    final Color primario = Color(0xFF6B3B2D);
    final Color secundario = Color(0xFF8D4F3A);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: primario,
        elevation: 0,
        title: const Text(
          'Centro de Soporte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                // Esto forzará una recarga de las peticiones
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: PeticionSupervisionService.obtenerPeticionesSupervision(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primario),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cargando peticiones de soporte...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al cargar peticiones',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No se pudieron cargar las peticiones de soporte',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        // Reintentar carga
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primario,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final result = snapshot.data;
          if (result == null || !result['success']) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 64,
                    color: Colors.orange[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudieron cargar las peticiones',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result?['message'] ?? 'Error desconocido',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          final peticiones = List<Map<String, dynamic>>.from(result['data'] ?? []);

          if (peticiones.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.support_agent_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay peticiones de soporte',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Las peticiones de supervisión aparecerán aquí',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Separar peticiones por estado
          final pendientes = peticiones.where((p) => 
            p['estado'] == 'pendiente' || p['estado'] == 'aceptada'
          ).toList();
          final procesadas = peticiones.where((p) => 
            p['estado'] == 'denegada' || p['estado'] == 'solucionada'
          ).toList();

          return Column(
            children: [
              // Estadísticas rápidas
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      'Total',
                      peticiones.length.toString(),
                      Icons.support_agent,
                      Colors.blue,
                    ),
                    _buildStatColumn(
                      'Pendientes',
                      pendientes.length.toString(),
                      Icons.schedule,
                      Colors.orange,
                    ),
                    _buildStatColumn(
                      'Aceptadas',
                      peticiones.where((p) => p['estado'] == 'aceptada').length.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                    _buildStatColumn(
                      'Denegadas',
                      peticiones.where((p) => p['estado'] == 'denegada').length.toString(),
                      Icons.cancel,
                      Colors.red,
                    ),
                  ],
                ),
              ),

              // Lista de peticiones
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TabBar(
                          indicator: BoxDecoration(
                            color: primario,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: primario,
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.schedule, size: 18),
                                  SizedBox(width: 8),
                                  Text('Pendientes (${pendientes.length})'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history, size: 18),
                                  SizedBox(width: 8),
                                  Text('Procesadas (${procesadas.length})'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Tab de peticiones pendientes
                            _buildPeticionesList(pendientes, true, primario, secundario),
                            // Tab de peticiones procesadas
                            _buildPeticionesList(procesadas, false, primario, secundario),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeticionesList(List<Map<String, dynamic>> peticiones, bool esPendiente, Color primario, Color secundario) {
    if (peticiones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              esPendiente ? Icons.schedule : Icons.history,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              esPendiente ? 'No hay peticiones pendientes' : 'No hay peticiones procesadas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              esPendiente ? 'Las nuevas peticiones aparecerán aquí' : 'Las peticiones procesadas aparecerán aquí',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: peticiones.length,
      itemBuilder: (context, index) {
        final peticion = peticiones[index];
        return _buildPeticionCard(peticion, esPendiente, primario, secundario);
      },
    );
  }

  Widget _buildPeticionCard(Map<String, dynamic> peticion, bool esPendiente, Color primario, Color secundario) {
    final estado = peticion['estado'] ?? 'pendiente';
    final prioridad = peticion['prioridad'] ?? 'media';
    final fechaCreacion = DateTime.tryParse(peticion['fechaCreacion'] ?? '') ?? DateTime.now();
    final tiempoTranscurrido = _getTimeSince(fechaCreacion);

    Color colorEstado;
    IconData iconoEstado;
    
    switch (estado) {
      case 'aceptada':
        colorEstado = Colors.green;
        iconoEstado = Icons.check_circle;
        break;
      case 'denegada':
        colorEstado = Colors.red;
        iconoEstado = Icons.cancel;
        break;
      case 'solucionada':
        colorEstado = Colors.blue;
        iconoEstado = Icons.check_circle_outline;
        break;
      default:
        colorEstado = Colors.orange;
        iconoEstado = Icons.schedule;
    }

    Color colorPrioridad;
    switch (prioridad) {
      case 'baja':
        colorPrioridad = Colors.green;
        break;
      case 'alta':
        colorPrioridad = Colors.red;
        break;
      case 'urgente':
        colorPrioridad = Colors.purple;
        break;
      default:
        colorPrioridad = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: esPendiente ? Border.all(color: colorPrioridad.withOpacity(0.3), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con usuario y estado
            Row(
              children: [
                // Avatar del usuario
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primario.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      (peticion['nombreUsuario'] ?? 'U').substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: primario,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Info del usuario
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peticion['nombreUsuario'] ?? 'Usuario desconocido',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        peticion['emailUsuario'] ?? '',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Estado y tiempo
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorEstado.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorEstado.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconoEstado, size: 12, color: colorEstado),
                          const SizedBox(width: 4),
                          Text(
                            PeticionSupervisionService.getTextoEstado(estado),
                            style: TextStyle(
                              color: colorEstado,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tiempoTranscurrido,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Prioridad y motivo
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorPrioridad.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Prioridad: ${PeticionSupervisionService.getTextoPrioridad(prioridad)}',
                    style: TextStyle(
                      color: colorPrioridad,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (peticion['motivo'] != null && peticion['motivo'].toString().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Motivo: ${peticion['motivo']}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Mensaje
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                peticion['mensaje'] ?? 'Sin mensaje',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            
            // Respuesta del admin si existe
            if (peticion['respuestaAdmin'] != null && peticion['respuestaAdmin'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorEstado.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorEstado.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 14, color: colorEstado),
                        const SizedBox(width: 4),
                        Text(
                          'Respuesta del administrador:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorEstado,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      peticion['respuestaAdmin'],
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Botones de acción según el estado específico
            if (estado == 'pendiente') ...[
              // Solo para peticiones verdaderamente pendientes
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _mostrarDialogoRespuesta(peticion, 'aceptar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Aceptar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _mostrarDialogoRespuesta(peticion, 'denegar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Denegar'),
                    ),
                  ),
                ],
              ),
            ] else if (estado == 'aceptada') ...[
              // Solo para peticiones aceptadas
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _abrirChatConUsuario(peticion),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primario,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('Ir al Chat'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _mostrarDialogoSolucionado(peticion),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Marcar Solucionado'),
                    ),
                  ),
                ],
              ),
            ],
            // Las peticiones denegadas y solucionadas no tienen botones de acción
          ],
        ),
      ),
    );
  }

  String _getTimeSince(DateTime fecha) {
    final now = DateTime.now();
    final difference = now.difference(fecha);

    if (difference.inDays > 0) {
      return 'hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'hace unos segundos';
    }
  }

  void _mostrarDialogoRespuesta(Map<String, dynamic> peticion, String accion) {
    final TextEditingController respuestaController = TextEditingController();
    final Color primario = Color(0xFF6B3B2D);
    final Color secundario = Color(0xFF8D4F3A);
    final bool esAceptar = accion == 'aceptar';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                esAceptar ? Icons.check_circle : Icons.cancel,
                color: esAceptar ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${esAceptar ? 'Aceptar' : 'Denegar'} Petición',
                  style: TextStyle(
                    color: primario,
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
              // Info de la petición
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Usuario: ${peticion['nombreUsuario']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mensaje: ${peticion['mensaje']}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Campo de respuesta
              Text(
                'Respuesta (opcional):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primario,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: respuestaController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: esAceptar 
                    ? 'Mensaje para el usuario sobre la aceptación...'
                    : 'Motivo del rechazo o explicación...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primario),
                  ),
                ),
              ),
            ],
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
              onPressed: () async {
                Navigator.of(context).pop();
                await _responderPeticion(
                  peticion['id'],
                  accion,
                  respuestaController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: esAceptar ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(esAceptar ? Icons.check : Icons.close, size: 18),
                  const SizedBox(width: 4),
                  Text(esAceptar ? 'Aceptar' : 'Denegar'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _responderPeticion(int idPeticion, String accion, String respuesta) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('${accion == 'aceptar' ? 'Aceptando' : 'Denegando'} petición...'),
            ],
          ),
        ),
      );

      final resultado = await PeticionSupervisionService.responderPeticionSupervision(
        idPeticion: idPeticion,
        accion: accion,
        respuesta: respuesta.isNotEmpty ? respuesta : null,
      );

      // Cerrar indicador de carga
      Navigator.of(context).pop();

      if (resultado['success']) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado['message'] ?? 'Petición procesada exitosamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Si se aceptó la petición, abrir el chat con el usuario
        if (accion == 'aceptar' && resultado['data'] != null) {
          final peticionData = resultado['data'];
          final rutUsuario = peticionData['rutUsuario'];
          final nombreUsuario = peticionData['nombreUsuario'];
          
          if (rutUsuario != null && nombreUsuario != null) {
            // Mostrar notificación de que se abrirá el chat
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Abriendo chat con $nombreUsuario...'),
                backgroundColor: Color(0xFF6B3B2D),
                duration: const Duration(seconds: 2),
              ),
            );

            // Esperar un momento para que se vea la notificación
            await Future.delayed(const Duration(milliseconds: 500));

            // Navegar al chat individual
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaginaIndividualWebSocket(
                  nombre: nombreUsuario,
                  rutAmigo: rutUsuario,
                  rutUsuarioAutenticado: null, // Se obtendrá automáticamente del storage
                ),
              ),
            );
          }
        }

        // Refrescar la vista
        setState(() {
          // Esto forzará una recarga de las peticiones
        });
      } else {
        // Mostrar error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${resultado['message']}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Cerrar indicador de carga si está abierto
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Mostrar error de conexión
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _abrirChatConUsuario(Map<String, dynamic> peticion) {
    final rutUsuario = peticion['rutUsuario'];
    final nombreUsuario = peticion['nombreUsuario'];
    
    if (rutUsuario != null && nombreUsuario != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaginaIndividualWebSocket(
            nombre: nombreUsuario,
            rutAmigo: rutUsuario,
            rutUsuarioAutenticado: null, // Se obtendrá automáticamente del storage
          ),
        ),
      );
    }
  }

  void _mostrarDialogoSolucionado(Map<String, dynamic> peticion) {
    final Color primario = Color(0xFF6B3B2D);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.blue,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Marcar como Solucionado',
                  style: TextStyle(
                    color: primario,
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
              // Info de la petición
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Usuario: ${peticion['nombreUsuario']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Petición: ${peticion['mensaje']}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Al marcar como solucionado:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '• El chat se cerrará automáticamente\n• El usuario podrá crear nuevas peticiones\n• Esta acción no se puede deshacer',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
              onPressed: () async {
                Navigator.of(context).pop();
                await _marcarComoSolucionado(peticion['id']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 18),
                  const SizedBox(width: 4),
                  Text('Marcar Solucionado'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _marcarComoSolucionado(int idPeticion) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Marcando petición como solucionada...'),
            ],
          ),
        ),
      );

      final resultado = await PeticionSupervisionService.marcarComoSolucionada(
        idPeticion: idPeticion,
      );

      // Cerrar indicador de carga
      Navigator.of(context).pop();

      if (resultado['success']) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado['message'] ?? 'Petición marcada como solucionada'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );

        // Refrescar la vista
        setState(() {
          // Esto forzará una recarga de las peticiones
        });
      } else {
        // Mostrar error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${resultado['message']}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Cerrar indicador de carga si está abierto
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Mostrar error de conexión
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B3B2D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, 
                     color: Colors.grey[400], size: 16),
              ],
            ),
          ),
        ),
      ));
  }

  Widget _buildStatColumn(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Usuario usuario) {
    final Color primario = Color(0xFF6B3B2D);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar con iniciales
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: usuario.esActivo ? primario : Colors.grey[400],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  usuario.iniciales,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Información del usuario
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          usuario.nombreCompleto,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF6B3B2D),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Badge del rol
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: usuario.rol == 'administrador' 
                              ? Colors.orange[100] 
                              : Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          usuario.rol == 'administrador' ? 'Admin' : 'Usuario',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: usuario.rol == 'administrador' 
                                ? Colors.orange[800] 
                                : Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  Text(
                    usuario.email,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  
                  if (usuario.carrera != null)
                    Text(
                      usuario.carrera!,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  const SizedBox(height: 4),
                  
                  Row(
                    children: [
                      Icon(
                        usuario.esActivo ? Icons.circle : Icons.circle_outlined,
                        size: 8,
                        color: usuario.esActivo ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        usuario.esActivo ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                          fontSize: 12,
                          color: usuario.esActivo ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Registrado hace ${usuario.tiempoRegistrado}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  
                  if (usuario.clasificacion != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 12,
                            color: Colors.amber[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Calificación: ${usuario.clasificacion!.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Botón de acciones
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'ver':
                    _mostrarDetallesUsuario(usuario);
                    break;
                  case 'editar':
                    _editarUsuario(usuario);
                    break;
                  case 'eliminar':
                    _confirmarEliminarUsuario(usuario);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'ver',
                  child: Row(
                    children: [
                      Icon(Icons.visibility),
                      SizedBox(width: 8),
                      Text('Ver Detalles'),
                    ],
                  ),
                ),
                // Solo mostrar opción de eliminar si no es administrador
                if (usuario.rol != 'administrador')
                  const PopupMenuItem(
                    value: 'eliminar',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
              child: Icon(
                Icons.more_vert,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetallesUsuario(Usuario usuario) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalles de ${usuario.nombreCompleto}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('RUT:', usuario.rut),
              _buildDetailRow('Email:', usuario.email),
              _buildDetailRow('Rol:', usuario.rol),
              _buildDetailRow('Edad:', usuario.edadTexto),
              if (usuario.carrera != null)
                _buildDetailRow('Carrera:', usuario.carrera!),
              if (usuario.altura != null)
                _buildDetailRow('Altura:', '${usuario.altura} cm'),
              if (usuario.peso != null)
                _buildDetailRow('Peso:', '${usuario.peso} kg'),
              if (usuario.clasificacion != null)
                _buildDetailRow('Calificación:', usuario.clasificacion!.toStringAsFixed(1)),
              _buildDetailRow('Estado:', usuario.esActivo ? 'Activo' : 'Inactivo'),
              _buildDetailRow('Registrado:', usuario.tiempoRegistrado),
              if (usuario.descripcion != null && usuario.descripcion!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Descripción:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(usuario.descripcion!),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _editarUsuario(Usuario usuario) {
    // TODO: Implementar edición de usuario
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función de edición en desarrollo'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _confirmarEliminarUsuario(Usuario usuario) {
    // Verificar si es seguro eliminar este usuario
    if (usuario.rol == 'administrador') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede eliminar un usuario administrador'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de que quieres eliminar al usuario ${usuario.nombreCompleto}?'
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción no se puede deshacer',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _eliminarUsuario(usuario);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _eliminarUsuario(Usuario usuario) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Eliminando usuario...'),
              const SizedBox(height: 8),
              Text(
                'Se están eliminando todas las relaciones del usuario',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // Llamar al servicio para eliminar el usuario completo
      final result = await UserService.eliminarUsuarioCompleto(usuario.rut);
      
      // Cerrar indicador de carga
      Navigator.of(context).pop();

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Usuario eliminado exitosamente'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Refrescar la lista de usuarios
      setState(() {
        // Esto forzará una recarga de los datos
      });

    } catch (e) {
      // Cerrar indicador de carga si está abierto
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar usuario: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
