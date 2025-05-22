import 'package:flutter/material.dart';
import 'auth/login.dart';
import 'mapa.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginPage(), // 👈 Comienza en verificación simulada
      routes: {
        '/mapa': (context) => const MapPage(),
      },
    );
  }
}