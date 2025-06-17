import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // IP de tu computadora en la red local
  static const String _localIP = '192.168.1.34';
  static const String _port = '3000';
    // URL base según la plataforma
  static String get baseUrl {
    if (kIsWeb) {
      // Para web usar localhost
      return 'http://localhost:$_port/api';    } else if (Platform.isAndroid || Platform.isIOS) {
      // Para emulador de Android Studio usar 10.0.2.2
      return 'http://10.0.2.2:$_port/api';
    } else {
      // Para desktop usar localhost
      return 'http://localhost:$_port/api';
    }
  }
  
  // URLs específicas
  static String get loginUrl => '$baseUrl/auth/login';
  static String get pingUrl => '$baseUrl/';
  static String get viajesUrl => '$baseUrl/viajes';
  static String get usersUrl => '$baseUrl/users';
  
  // Método para verificar conectividad
  static Future<bool> testConnection() async {
    try {
      final response = await HttpClient()
          .getUrl(Uri.parse(pingUrl))
          .timeout(Duration(seconds: 5));
      
      final httpResponse = await response.close();
      return httpResponse.statusCode == 200;
    } catch (e) {
      print('❌ Error de conectividad: $e');
      return false;
    }
  }
  
  // Información de debug
  static void printConfig() {
    print('🔧 Configuración API:');
    print('   Platform: ${Platform.operatingSystem}');
    print('   Base URL: $baseUrl');
    print('   Login URL: $loginUrl');
    print('   Is Web: $kIsWeb');
    print('   Is Android: ${Platform.isAndroid}');
  }
}
