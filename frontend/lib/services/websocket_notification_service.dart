import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/confGlobal.dart';
import '../utils/token_manager.dart';
import 'navigation_service.dart';

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
      
      // Escuchar notificaciones específicas de amistad
      _socket!.on('solicitud_amistad', (data) {
        print('👋 solicitud_amistad recibida: $data');
        _handleFriendRequestNotification(data);
      });
      
      _socket!.on('solicitud_viaje', (data) {
        print('🚗 solicitud_viaje recibida: $data');
        _handleTripRequestNotification(data);
      });
      
      _socket!.on('amistad_aceptada', (data) {
        print('🎉 amistad_aceptada recibida: $data');
        _handleFriendAcceptedNotification(data);
      });
      
      _socket!.on('amistad_rechazada', (data) {
        print('😔 amistad_rechazada recibida: $data');
        _handleFriendRejectedNotification(data);
      });
      
      // Escuchar nueva_notificacion - SOLO para notificaciones genéricas
      _socket!.on('nueva_notificacion', (data) {
        print('📩 nueva_notificacion recibida: $data');
        final notification = data is String ? json.decode(data) : data;
        final tipo = notification['datos']?['tipo'] ?? notification['tipo'];
        
        print('🔍 Tipo de notificación detectado: $tipo');
        
        // EXCLUIR eventos de amistad para evitar duplicados (ya procesados por eventos específicos)
        if (tipo == 'amistad_aceptada') {
          print('🎉 *** SALTANDO amistad_aceptada - ya procesada por evento específico ***');
          return; // NO procesar aquí
        } else if (tipo == 'amistad_rechazada') {
          print('😔 *** SALTANDO amistad_rechazada - ya procesada por evento específico ***');
          return; // NO procesar aquí
        } else if (tipo == 'solicitud_amistad') {
          print('👋 SALTANDO solicitud_amistad - ya procesada por evento específico');
          return; // NO procesar aquí
        } else {
          print('📝 Procesando notificación genérica');
          _handleIncomingNotification(data);
        }
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
  
  /// Manejar notificación de solicitud de viaje
  static void _handleTripRequestNotification(dynamic data) {
    try {
      print('🚗 *** PROCESANDO SOLICITUD DE VIAJE ***: $data');
      
      final notification = data is String ? json.decode(data) : data;
      print('🚗 *** DATOS PARSEADOS VIAJE ***: $notification');
      
      // Extraer información de la solicitud de viaje
      final rutEmisor = notification['rutEmisor'] ?? '';
      final nombreEmisor = notification['nombreEmisor'] ?? 'Usuario desconocido';
      final origen = notification['datos']?['origen'] ?? 'Origen desconocido';
      final destino = notification['datos']?['destino'] ?? 'Destino desconocido';
      final precio = notification['datos']?['precio'] ?? 0;
      
      print('🚗 *** MOSTRANDO NOTIFICACIÓN DE SOLICITUD DE VIAJE ***');
      print('🚗 Emisor: $nombreEmisor (RUT: $rutEmisor)');
      print('🚗 Viaje: $origen → $destino (\$$precio)');
      
      _showLocalNotification(
        title: '🚗 Nueva solicitud de viaje',
        body: '$nombreEmisor quiere unirse a tu viaje $origen → $destino (\$$precio)',
        payload: json.encode({
          'tipo': 'solicitud_viaje',
          'rutEmisor': rutEmisor,
          'nombreEmisor': nombreEmisor,
          'origen': origen,
          'destino': destino,
          'precio': precio,
          'viajeId': notification['viajeId'],
        }),
        isTripRequest: true,
      );
      
      print('✅ Notificación de solicitud de viaje procesada correctamente');
    } catch (e) {
      print('❌ Error procesando solicitud de viaje: $e');
      print('❌ Data recibida: $data');
      
      // Fallback: mostrar notificación genérica
      _showLocalNotification(
        title: '🚗 Nueva solicitud de viaje',
        body: 'Tienes una nueva solicitud para tu viaje',
        payload: json.encode({'tipo': 'solicitud_viaje_fallback'}),
        isTripRequest: true,
      );
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
      print('🎉 Procesando amistad aceptada: $data');
      
      final notification = data is String ? json.decode(data) : data;
      
      // El backend envía nombreReceptor (quien aceptó) al emisor original de la solicitud
      final nombreReceptor = notification['nombreReceptor'] ?? 'Usuario desconocido';
      final rutReceptor = notification['rutReceptor'] ?? '';
      
      _showLocalNotification(
        title: '🎉 ¡Nueva amistad!',
        body: 'Ahora eres amigo de $nombreReceptor',
        payload: json.encode({
          'tipo': 'amistad_aceptada',
          'rutReceptor': rutReceptor,
          'nombreReceptor': nombreReceptor,
        }),
      );
      
      print('✅ Notificación de amistad aceptada procesada correctamente');
    } catch (e) {
      print('❌ Error procesando amistad aceptada: $e');
      
      // Notificación de respaldo
      _showLocalNotification(
        title: '🎉 ¡Nueva amistad!',
        body: 'Tu solicitud de amistad fue aceptada',
        payload: json.encode({'tipo': 'amistad_aceptada_fallback'}),
      );
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
  
  /// Mostrar notificación local pública (para uso externo)
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }
  
  /// Mostrar notificación local
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    bool isTripRequest = false,
  }) async {
    try {
      print('🔔 *** INTENTANDO MOSTRAR NOTIFICACIÓN ***: $title - $body');
      print('🔔 *** PAYLOAD ***: $payload');
      
      if (_flutterLocalNotificationsPlugin == null) {
        print('❌ Plugin de notificaciones no inicializado');
        return;
      }
      
      // Verificar permisos antes de mostrar
      final androidImplementation = _flutterLocalNotificationsPlugin!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        bool? enabled = await androidImplementation.areNotificationsEnabled();
        print('🔔 *** PERMISOS DE NOTIFICACIONES HABILITADOS ***: $enabled');
      }
      
      // Determinar si es una solicitud (amistad o viaje) para agregar botones
      bool esSolicitud = isTripRequest;
      String tipoSolicitud = 'generico';
      
      try {
        if (payload != null) {
          final data = json.decode(payload);
          final tipo = data['tipo'];
          if (tipo == 'solicitud_amistad') {
            esSolicitud = true;
            tipoSolicitud = 'amistad';
          } else if (tipo == 'solicitud_viaje') {
            esSolicitud = true;
            tipoSolicitud = 'viaje';
          }
        }
      } catch (e) {
        print('❌ Error parseando payload para determinar tipo: $e');
      }
      
      AndroidNotificationDetails androidNotificationDetails;
      
      if (esSolicitud) {
        // Notificación con botones de acción según el tipo
        List<AndroidNotificationAction> actions = [];
        
        if (tipoSolicitud == 'amistad') {
          actions = [
            AndroidNotificationAction(
              'view_request',
              'Ver solicitud',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ];
        } else if (tipoSolicitud == 'viaje') {
          actions = [
            AndroidNotificationAction(
              'accept_trip',
              'Aceptar',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'reject_trip',
              'Rechazar',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'view_trip_request',
              'Ver detalles',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ];
        }
        
        androidNotificationDetails = AndroidNotificationDetails(
          'bioruta_channel',
          'BioRuta Notificaciones',
          channelDescription: 'Notificaciones de la aplicación BioRuta',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: tipoSolicitud == 'viaje' ? Color(0xFF854937) : Color(0xFF2E7D32),
          enableVibration: true,
          playSound: true,
          showWhen: true,
          channelShowBadge: true,
          onlyAlertOnce: false,
          autoCancel: false, // No auto-cancelar para que el usuario pueda ver los botones
          ongoing: false,
          silent: false,
          enableLights: true,
          ledColor: tipoSolicitud == 'viaje' ? Color(0xFF854937) : Color(0xFF2E7D32),
          ledOnMs: 1000,
          ledOffMs: 500,
          ticker: 'BioRuta',
          actions: actions,
        );
      } else {
        // Notificación normal sin botones
        androidNotificationDetails = const AndroidNotificationDetails(
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
          channelShowBadge: true,
          onlyAlertOnce: false,
          autoCancel: true,
          ongoing: false,
          silent: false,
          enableLights: true,
          ledColor: Color(0xFF2E7D32),
          ledOnMs: 1000,
          ledOffMs: 500,
          ticker: 'BioRuta',
        );
      }
      
      const DarwinNotificationDetails iOSNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      );
      
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iOSNotificationDetails,
      );
      
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      print('🔔 *** MOSTRANDO NOTIFICACIÓN CON ID ***: $notificationId');
      
      await _flutterLocalNotificationsPlugin!.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      
      print('✅ *** NOTIFICACIÓN ENVIADA AL SISTEMA ANDROID CON ID ***: $notificationId');
      
    } catch (e, stackTrace) {
      print('❌ *** ERROR MOSTRANDO NOTIFICACIÓN ***: $e');
      print('❌ *** STACK TRACE ***: $stackTrace');
    }
  }
  
  /// Manejar tap en notificación y acciones de botones
  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    final actionId = notificationResponse.actionId;
    
    if (payload != null) {
      try {
        final data = json.decode(payload);
        print('📱 Notificación procesada: ${data['tipo']}, Acción: $actionId');
        
        // Manejar acciones de botones específicas para solicitudes de amistad
        if (data['tipo'] == 'solicitud_amistad') {
          switch (actionId) {
            case 'view_request':
              print('👀 Usuario presionó "Ver solicitud" en la notificación del sistema');
              _navigateToNotifications();
              break;
            default:
              // Tap normal en la notificación (sin botón específico)
              print('📱 Tap normal en notificación de solicitud de amistad');
              _navigateToNotifications();
              break;
          }
        } else {
          // Manejar otros tipos de notificaciones
          switch (data['tipo']) {
            case 'amistad_aceptada':
            case 'amistad_rechazada':
              _navigateToFriends();
              break;
            default:
              _navigateToNotifications();
              break;
          }
        }
      } catch (e) {
        print('❌ Error procesando tap en notificación: $e');
      }
    }
  }
  
  /// Navegar a la pantalla de notificaciones
  static void _navigateToNotifications() {
    print('🔄 Navegando a pantalla de solicitudes...');
    NavigationService.navigateToRequests();
  }
  
  /// Navegar a la pantalla de amigos
  static void _navigateToFriends() {
    print('🔄 Navegando a pantalla de amigos...');
    NavigationService.navigateToFriends();
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
  
  /// Verificar y solicitar permisos de notificación
  static Future<bool> checkAndRequestPermissions() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      final androidImplementation = _flutterLocalNotificationsPlugin!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        // Verificar si están habilitadas
        bool? enabled = await androidImplementation.areNotificationsEnabled();
        print('🔔 Notificaciones habilitadas: $enabled');
        
        if (enabled == false) {
          // Solicitar permisos
          bool? granted = await androidImplementation.requestNotificationsPermission();
          print('🔔 Permisos solicitados, resultado: $granted');
          return granted ?? false;
        }
        
        return enabled ?? false;
      }
      
      return true; // Para iOS u otras plataformas
    } catch (e) {
      print('❌ Error verificando permisos: $e');
      return false;
    }
  }
}
