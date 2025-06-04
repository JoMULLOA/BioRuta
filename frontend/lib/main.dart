import 'package:flutter/material.dart';
import 'auth/login.dart';
import 'viaje/mapa.dart';
import 'screens/inicio.dart';
import 'screens/publicar.dart';
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
      home: const LoginPage(),
      routes: {
        '/inicio': (context) => const InicioScreen(),
        '/mapa': (context) => const MapPage(),
        '/publicar': (context) => PublicarPage(),
        
      },
    );
  }
}
