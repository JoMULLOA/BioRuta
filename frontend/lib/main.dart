import 'package:BioRuta/Ranking/ranking.dart';
import 'package:flutter/material.dart';
import 'auth/login.dart';
import 'mapa/mapa.dart';
import 'viajes/mapa_viajes_screen.dart';
import 'mis_viajes/mis_viajes_screen.dart';
import 'buscar/inicio.dart';
import 'publicar/publicar.dart';
import 'chat/chat.dart';
import 'perfil/perfil.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioRuta',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const LoginPage(),      routes: {
        '/inicio': (context) => const InicioScreen(),
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
