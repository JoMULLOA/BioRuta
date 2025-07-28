import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/websocket_notification_service.dart';
import 'auth/login.dart';
import 'mapa/mapa.dart';
import 'viajes/mapa_viajes_screen.dart';
import 'mis_viajes/mis_viajes_screen.dart';
import 'buscar/inicio.dart';
import 'publicar/publicar.dart';
import 'chat/chat.dart';
import 'perfil/perfil.dart';
import 'perfil/notificaciones.dart';
import 'perfil/amistad_menu.dart';
import 'services/viaje_estado_service.dart';
import 'services/navigation_service.dart';
import 'Ranking/ranking.dart';
import 'sos/sos_screen.dart';
import 'admin/admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar servicio de estado de viaje
  ViajeEstadoService.instance.initialize();
  
  try {
    // Inicializar sistema de notificaciones WebSocket
    await WebSocketNotificationService.initialize();
    
    // Configurar callback para diálogos in-app
    WebSocketNotificationService.setInAppDialogCallback((title, message, {action}) {
      final context = NavigationService.navigatorKey.currentContext;
      if (context != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (action == 'passenger_eliminated') {
                    // Redirigir a la pantalla de mis viajes después de eliminar
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/mis-viajes',
                      (route) => false,
                    );
                  }
                },
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    });
    
    print('🔔 Sistema de notificaciones WebSocket inicializado');
  } catch (e) {
    print('❌ Error inicializando notificaciones: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      title: 'BioRuta',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'ES'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      initialRoute: '/login', // Ruta inicial
      onGenerateRoute: (settings) {
        // Manejar rutas con argumentos personalizados
        switch (settings.name) {
          case '/admin':
            final args = settings.arguments as Map<String, dynamic>?;
            final initialTab = args?['initialTab'] as int?;
            return MaterialPageRoute(
              builder: (context) => AdminDashboard(initialTab: initialTab),
            );
          default:
            return null; // Usar rutas predefinidas
        }
      },
      routes: {
        '/': (context) => const MisViajesScreen(), // Ruta principal ahora es mis viajes
        '/login': (context) => const LoginPage(),
        '/inicio': (context) => const InicioScreen(),
        '/buscar': (context) => const InicioScreen(),
        '/mapa': (context) => const MapPage(),
        '/viajes': (context) => const MapaViajesScreen(),
        '/mis-viajes': (context) => const MisViajesScreen(),
        '/publicar': (context) => const PublicarPage(),
        '/chat': (context) => Chat(),
        '/ranking': (context) => ranking(),
        '/sos': (context) => const SOSScreen(),
        '/perfil': (context) => Perfil(),
        '/amistades': (context) => AmistadMenuScreen(),
        '/solicitudes': (context) => NotificacionesScreen(),
      },
    );
  }
}

