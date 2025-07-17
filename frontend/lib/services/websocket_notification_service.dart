import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/confGlobal.dart';
import '../utils/token_manager.dart';

class WebSocketNotificationService {
  static IO.Socket? _socket;
  static FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;
  static bool _isInitialized = false;
  static String? _currentUserRut;
  
  /// Inicializar el servicio de notificaciones WebSocket
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Inicializar notificaciones locales
      await _initializeLocalNotifications();
      
      print('✅ Servicio de notificaciones WebSocket listo');
      _isInitialized = true;
    } catch (e) {
      print('❌ Error inicializando notificaciones WebSocket: $e');
      throw e;
    }
  }
  
  /// Inicializar notificaciones locales de Flutter
  static Future<void> _initializeLocalNotifications() async {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Configuración Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin!.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Crear canal de notificaciones Android explícitamente
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'bioruta_channel',
      'BioRuta Notificaciones',
      description: 'Notificaciones de amistad y eventos de BioRuta',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _flutterLocalNotificationsPlugin!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    // Solicitar permisos en Android 13+
    final androidImplementation = _flutterLocalNotificationsPlugin!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      final bool? exactAlarmPermission = await androidImplementation.requestExactAlarmsPermission();
      print('🔔 Permisos de notificaciones: exactAlarms=$exactAlarmPermission');
    }
    
    print('✅ Notificaciones locales inicializadas correctamente');
  }
  
  /// Conectar al WebSocket cuando el usuario inicie sesión
  static Future<void> connectToSocket(String userRut) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    _currentUserRut = userRut;
    
    try {
      final token = await TokenManager.getValidToken();
      if (token == null) {
        print('❌ No hay token válido para conectar WebSocket');
        return;
      }
      
      // Desconectar socket anterior si existe
      if (_socket != null) {
        _socket!.disconnect();
      }
      
      // Configurar opciones del socket
      final socketUrl = confGlobal.baseUrl.replaceAll('/api', ''); // Remover /api para Socket.io
      print('🔌 Conectando WebSocket a: $socketUrl');
      
      _socket = IO.io(socketUrl, IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({
            'token': token,
            'userRut': userRut,
          })
          .setPath('/socket.io/')
          .enableAutoConnect()
          .build());
      
      // Eventos del socket
      _socket!.onConnect((_) {
        print('🔗 WebSocket conectado para notificaciones del usuario $userRut');
        _socket!.emit('joinUserRoom', userRut);
        
        // Confirmar que estamos escuchando los eventos correctos
        print('🔔 Configurados listeners para: nueva_notificacion, solicitud_amistad, amistad_aceptada, amistad_rechazada');
      });
      
      _socket!.onDisconnect((_) {
        print('📴 WebSocket desconectado');
      });
      
      _socket!.onConnectError((error) {
        print('❌ Error de conexión WebSocket: $error');
      });
      
      _socket!.onError((error) {
        print('❌ Error en WebSocket: $error');
      });
      
      // Escuchar TODOS los eventos para debugging
      _socket!.onAny((event, data) {
        print('🎧 Evento WebSocket recibido: $event con data: $data');
      });
      
      // Escuchar notificaciones específicas
      _socket!.on('nueva_notificacion', (data) {
        print('📩 nueva_notificacion recibida: $data');
        _handleIncomingNotification(data);
      });
      
      _socket!.on('solicitud_amistad', (data) {
        print('👋 solicitud_amistad recibida: $data');
        _handleFriendRequestNotification(data);
      });
      
      _socket!.on('amistad_aceptada', (data) {
        print('🎉 amistad_aceptada recibida: $data');
        _handleFriendAcceptedNotification(data);
      });
      
      _socket!.on('amistad_rechazada', (data) {
        print('😔 amistad_rechazada recibida: $data');
        _handleFriendRejectedNotification(data);
      });
      
      // Escuchar confirmación de conexión
      _socket!.on('notification_connection_confirmed', (data) {
        print('✅ Conexión de notificaciones confirmada: $data');
      });
      
      _socket!.connect();
      
    } catch (e) {
      print('❌ Error conectando WebSocket: $e');
    }
  }
  
  /// Desconectar del WebSocket
  static void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _currentUserRut = null;
      print('📴 WebSocket desconectado manualmente');
    }
  }
  
  /// Manejar notificación entrante general
  static void _handleIncomingNotification(dynamic data) {
    try {
      final notification = data is String ? json.decode(data) : data;
      
      _showLocalNotification(
        title: notification['titulo'] ?? 'Nueva notificación',
        body: notification['mensaje'] ?? '',
        payload: json.encode(notification),
      );
      
      print('🔔 Notificación recibida: ${notification['titulo']}');
    } catch (e) {
      print('❌ Error procesando notificación: $e');
    }
  }
  
  /// Manejar notificación de solicitud de amistad
  static void _handleFriendRequestNotification(dynamic data) {
    try {
      print('🔧 Procesando solicitud de amistad: $data');
      
      final notification = data is String ? json.decode(data) : data;
      print('🔧 Datos parseados: $notification');
      
      final nombreEmisor = notification['nombreEmisor'] ?? 'Usuario desconocido';
      final rutEmisor = notification['rutEmisor'] ?? '';
      
      print('🔧 Mostrando notificación para: $nombreEmisor (RUT: $rutEmisor)');
      
      _showLocalNotification(
        title: '👋 Nueva solicitud de amistad',
        body: '$nombreEmisor te ha enviado una solicitud de amistad',
        payload: json.encode({
          'tipo': 'solicitud_amistad',
          'rutEmisor': rutEmisor,
          'nombreEmisor': nombreEmisor,
        }),
      );
      
      print('✅ Notificación de solicitud de amistad procesada correctamente');
    } catch (e) {
      print('❌ Error procesando solicitud de amistad: $e');
      print('❌ Data recibida: $data');
      
      // Fallback: mostrar notificación genérica
      _showLocalNotification(
        title: '👋 Nueva solicitud de amistad',
        body: 'Has recibido una nueva solicitud de amistad',
        payload: json.encode({'tipo': 'solicitud_amistad_fallback'}),
      );
    }
  }
  
  /// Manejar notificación de amistad aceptada
  static void _handleFriendAcceptedNotification(dynamic data) {
    try {
      final notification = data is String ? json.decode(data) : data;
      
      _showLocalNotification(
        title: '🎉 ¡Solicitud aceptada!',
        body: '${notification['nombreReceptor']} aceptó tu solicitud de amistad',
        payload: json.encode({
          'tipo': 'amistad_aceptada',
          'rutReceptor': notification['rutReceptor'],
          'nombreReceptor': notification['nombreReceptor'],
        }),
      );
      
      print('🎉 Amistad aceptada por: ${notification['nombreReceptor']}');
    } catch (e) {
      print('❌ Error procesando amistad aceptada: $e');
    }
  }
  
  /// Manejar notificación de amistad rechazada
  static void _handleFriendRejectedNotification(dynamic data) {
    try {
      final notification = data is String ? json.decode(data) : data;
      
      _showLocalNotification(
        title: '😔 Solicitud rechazada',
        body: '${notification['nombreReceptor']} rechazó tu solicitud de amistad',
        payload: json.encode({
          'tipo': 'amistad_rechazada',
          'rutReceptor': notification['rutReceptor'],
          'nombreReceptor': notification['nombreReceptor'],
        }),
      );
      
      print('😔 Amistad rechazada por: ${notification['nombreReceptor']}');
    } catch (e) {
      print('❌ Error procesando amistad rechazada: $e');
    }
  }
  
  /// Mostrar notificación local
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (_flutterLocalNotificationsPlugin == null) return;
    
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'bioruta_channel',
      'BioRuta Notificaciones',
      channelDescription: 'Notificaciones de la aplicación BioRuta',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF2E7D32),
      enableVibration: true,
      playSound: true,
      showWhen: true,
      when: null,
      usesChronometer: false,
      channelShowBadge: true,
      onlyAlertOnce: false,
      autoCancel: true,
      ongoing: false,
      silent: false,
      enableLights: true,
      ledColor: Color(0xFF2E7D32),
      ledOnMs: 1000,
      ledOffMs: 500,
    );
    
    const DarwinNotificationDetails iOSNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iOSNotificationDetails,
    );
    
    await _flutterLocalNotificationsPlugin!.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
    
    print('📱 Notificación local mostrada: $title - $body');
  }
  
  /// Manejar tap en notificación
  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    if (payload != null) {
      try {
        final data = json.decode(payload);
        print('📱 Notificación tocada: ${data['tipo']}');
        
        // Aquí puedes navegar a diferentes pantallas según el tipo
        switch (data['tipo']) {
          case 'solicitud_amistad':
            // Navegar a pantalla de solicitudes de amistad
            break;
          case 'amistad_aceptada':
          case 'amistad_rechazada':
            // Navegar a pantalla de amigos
            break;
        }
      } catch (e) {
        print('❌ Error procesando tap en notificación: $e');
      }
    }
  }
  
  /// Verificar si el servicio está conectado
  static bool get isConnected => _socket?.connected ?? false;
  
  /// Obtener el RUT del usuario actual
  static String? get currentUserRut => _currentUserRut;
  
  /// Función de prueba para verificar notificaciones
  static Future<void> testNotification() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    await _showLocalNotification(
      title: '🧪 Prueba de notificación',
      body: 'Si ves esto, las notificaciones funcionan correctamente',
      payload: json.encode({'tipo': 'test'}),
    );
  }
}
