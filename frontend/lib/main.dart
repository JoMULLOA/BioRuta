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
import 'Ranking/ranking.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Inicializar sistema de notificaciones WebSocket
    await WebSocketNotificationService.initialize();
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
        '/perfil': (context) => Perfil(),
      },
    );
  }
}
