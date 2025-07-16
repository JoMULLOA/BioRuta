import 'package:flutter/material.dart';
import '../widgets/admin_navbar.dart';
import 'admin_profile.dart';
import 'admin_stats.dart';
import '../services/user_service.dart';

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

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: primario,
        elevation: 0,
        title: const Text(
          'Soporte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.support_agent, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Centro de Soporte',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Próximamente...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
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
      ),
    );
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Estás seguro de que quieres eliminar al usuario ${usuario.nombreCompleto}?'
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

  void _eliminarUsuario(Usuario usuario) {
    // TODO: Implementar eliminación de usuario
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función de eliminación en desarrollo'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
