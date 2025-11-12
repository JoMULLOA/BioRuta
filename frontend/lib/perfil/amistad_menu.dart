import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../perfil/solicitudes.dart';
import '../perfil/amigos.dart';
import '../perfil/notificaciones.dart';
import '../utils/custom_app_bar.dart';
import '../config/app_colors.dart';
import '../providers/theme_provider.dart';

class AmistadMenuScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final primaryColor = themeProvider.isDarkMode 
            ? AppColors.primaryDark 
            : AppColors.primaryLight;
        final backgroundColor = themeProvider.isDarkMode 
            ? AppColors.darkBackground 
            : AppColors.lightBackground;
        
        return Scaffold(
          backgroundColor: backgroundColor,
      appBar: CustomAppBar(
        title: 'Amistades',
        showNotifications: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título principal
            Text(
              'Gestiona tus Amistades',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Conecta con otros usuarios de BioRuta',
              style: TextStyle(
                fontSize: 16,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 30),

            // Tarjetas de opciones
            _buildOptionCard(
              context,
              icon: Icons.notifications_active,
              title: 'Solicitudes',
              subtitle: 'Gestiona las solicitudes de amistad pendientes',
              color: Colors.orange,
              primaryColor: primaryColor,
              backgroundColor: backgroundColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NotificacionesScreen()),
                );
              },
            ),

            const SizedBox(height: 16),

            _buildOptionCard(
              context,
              icon: Icons.person_add,
              title: 'Agregar Amigos',
              subtitle: 'Busca y envía solicitudes de amistad',
              color: Colors.blue,
              primaryColor: primaryColor,
              backgroundColor: backgroundColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Solicitud()),
                );
              },
            ),

            const SizedBox(height: 16),

            _buildOptionCard(
              context,
              icon: Icons.people,
              title: 'Mis Amigos',
              subtitle: 'Ve tu lista de amigos y chatea con ellos',
              color: Colors.green,
              primaryColor: primaryColor,
              backgroundColor: backgroundColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AmigosScreen()),
                );
              },
            ),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color primaryColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    final surfaceColor = backgroundColor == AppColors.darkBackground 
        ? AppColors.darkSurface 
        : Colors.white;
        
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: backgroundColor == AppColors.darkBackground 
                              ? AppColors.darkText 
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: backgroundColor == AppColors.darkBackground 
                              ? AppColors.darkSecondaryText 
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: backgroundColor == AppColors.darkBackground 
                      ? AppColors.darkSecondaryText 
                      : Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
