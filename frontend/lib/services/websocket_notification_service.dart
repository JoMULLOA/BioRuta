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
  
  // Cache para evitar notificaciones duplicadas
  static final Set<String> _processedNotifications = <String>{};
  static const int _maxCacheSize = 100; // Límite del cache
  
  // Callbacks para eventos de solicitudes
  static VoidCallback? _onTripRequestReceived;
  static VoidCallback? _onTripRequestProcessed;
  
  /// Generar ID único para la notificación basado en contenido
  static String _generateNotificationId(dynamic data) {
    try {
      final notification = data is String ? json.decode(data) : data;
      
      // Generar ID basado en el tipo, emisor y timestamp
      final tipo = notification['tipo'] ?? '';
      final rutEmisor = notification['rutEmisor'] ?? '';
      final timestamp = notification['timestamp'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      return '$tipo-$rutEmisor-$timestamp';
    } catch (e) {
      // Si no se puede generar ID específico, usar timestamp + tipo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'notification-$timestamp';
    }
  }
  
  /// Verificar si la notificación ya fue procesada
  static bool _isNotificationProcessed(String notificationId) {
    // Limpiar cache si está muy grande
    if (_processedNotifications.length > _maxCacheSize) {
      _processedNotifications.clear();
      print('🧹 Cache de notificaciones limpiado');
    }
    
    if (_processedNotifications.contains(notificationId)) {
      print('🚫 Notificación duplicada detectada y bloqueada: $notificationId');
      return true;
    }
    
    _processedNotifications.add(notificationId);
    print('✅ Nueva notificación registrada: $notificationId');
    return false;
  }
  
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
  
  /// Registrar callback para cuando se reciba una nueva solicitud de viaje
  static void setOnTripRequestReceived(VoidCallback? callback) {
    _onTripRequestReceived = callback;
  }
  
  /// Registrar callback para cuando se procese una solicitud de viaje
  static void setOnTripRequestProcessed(VoidCallback? callback) {
    _onTripRequestProcessed = callback;
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
      
      _socket!.on('ride_accepted', (data) {
        print('🎉 ride_accepted recibida: $data');
        _handleTripAcceptedNotification(data);
      });
      
      _socket!.on('ride_rejected', (data) {
        print('😔 ride_rejected recibida: $data');
        _handleTripRejectedNotification(data);
      });
      
      _socket!.on('pasajero_eliminado', (data) {
        print('🚫 pasajero_eliminado recibida: $data');
        _handlePassengerRemovedNotification(data);
      });
      
      _socket!.on('amistad_aceptada', (data) {
        print('🎉 amistad_aceptada recibida: $data');
        _handleFriendAcceptedNotification(data);
      });
      
      _socket!.on('amistad_rechazada', (data) {
        print('😔 amistad_rechazada recibida: $data');
        _handleFriendRejectedNotification(data);
      });
      
      // Escuchar notificaciones de chat individual
      _socket!.on('chat_individual', (data) {
        print('💬 chat_individual recibida: $data');
        _handleChatIndividualNotification(data);
      });
      
      // Escuchar notificaciones de chat grupal
      _socket!.on('chat_grupal', (data) {
        print('👥 chat_grupal recibida: $data');
        _handleChatGrupalNotification(data);
      });
      
      _socket!.on('nueva_peticion_soporte', (data) {
        print('🆘 nueva_peticion_soporte recibida: $data');
        _handleSupportRequestNotification(data);
      });
      
      // DESHABILITADO: nueva_notificacion - Solo usamos eventos específicos para evitar duplicados
      // Los eventos específicos (solicitud_amistad, amistad_aceptada, etc.) manejan todas las notificaciones
      /*
      _socket!.on('nueva_notificacion', (data) {
        print('� nueva_notificacion recibida (IGNORADA): $data');
        // Este evento está deshabilitado para evitar notificaciones duplicadas
        // Todos los tipos de notificación se procesan mediante eventos específicos
      });
      */
      
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
      
      // Limpiar cache de notificaciones al desconectar
      _processedNotifications.clear();
      print('🧹 Cache de notificaciones limpiado al desconectar');
      
      print('📴 WebSocket desconectado manualmente');
    }
  }
  
  /// Manejar notificación de solicitud de viaje
  static void _handleTripRequestNotification(dynamic data) {
    try {
      print('🚗 *** PROCESANDO SOLICITUD DE VIAJE ***: $data');
      
      // Verificar duplicados antes de procesar
      final notificationId = _generateNotificationId(data);
      if (_isNotificationProcessed(notificationId)) {
        return; // Notificación duplicada, no procesar
      }
      
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
      );
      
      // Llamar al callback si está registrado
      _onTripRequestReceived?.call();
      
      print('✅ Notificación de solicitud de viaje procesada correctamente');
    } catch (e) {
      print('❌ Error procesando solicitud de viaje: $e');
      print('❌ Data recibida: $data');
      
      // Fallback: mostrar notificación genérica
      _showLocalNotification(
        title: '🚗 Nueva solicitud de viaje',
        body: 'Tienes una nueva solicitud para tu viaje',
        payload: json.encode({'tipo': 'solicitud_viaje_fallback'}),
      );
    }
  }

  /// Manejar notificación de solicitud de amistad
  static void _handleFriendRequestNotification(dynamic data) {
    try {
      print('🔧 Procesando solicitud de amistad: $data');
      
      // Verificar duplicados antes de procesar
      final notificationId = _generateNotificationId(data);
      if (_isNotificationProcessed(notificationId)) {
        return; // Notificación duplicada, no procesar
      }
      
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
      
      // Verificar duplicados antes de procesar
      final notificationId = _generateNotificationId(data);
      if (_isNotificationProcessed(notificationId)) {
        return; // Notificación duplicada, no procesar
      }
      
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
      // Verificar duplicados antes de procesar
      final notificationId = _generateNotificationId(data);
      if (_isNotificationProcessed(notificationId)) {
        return; // Notificación duplicada, no procesar
      }
      
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
  
  /// Manejar notificación de viaje aceptado
  static void _handleTripAcceptedNotification(dynamic data) {
    try {
      print('🔧 *** PROCESANDO VIAJE ACEPTADO ***: $data');
      
      // Verificar duplicados antes de procesar
      final notificationId = _generateNotificationId(data);
      if (_isNotificationProcessed(notificationId)) {
        return; // Notificación duplicada, no procesar
      }
      
      final notification = data is String ? json.decode(data) : data;
      print('🔧 *** DATOS PARSEADOS VIAJE ACEPTADO ***: $notification');
      
      final nombreEmisor = notification['nombreEmisor'] ?? 'Conductor';
      final origen = notification['origen'] ?? '';
      final destino = notification['destino'] ?? '';
      final viajeId = notification['viajeId'] ?? '';
      
      print('🔧 *** MOSTRANDO NOTIFICACIÓN DE VIAJE ACEPTADO por: $nombreEmisor ***');
      
      _showLocalNotification(
        title: '🎉 ¡Viaje aceptado!',
        body: '$nombreEmisor aceptó tu solicitud para el viaje de $origen a $destino',
        payload: json.encode({
          'tipo': 'ride_accepted',
          'rutEmisor': notification['rutEmisor'],
          'nombreEmisor': nombreEmisor,
          'viajeId': viajeId,
          'origen': origen,
          'destino': destino,
          'mostrarAnimacion': true,
        }),
      );
      
      // Llamar al callback para actualizar la UI del conductor
      _onTripRequestProcessed?.call();
      
      print('✅ *** NOTIFICACIÓN DE VIAJE ACEPTADO PROCESADA CORRECTAMENTE ***');
    } catch (e) {
      print('❌ *** ERROR PROCESANDO VIAJE ACEPTADO ***: $e');
      print('❌ *** DATA RECIBIDA ***: $data');
      
      // Notificación de respaldo
      _showLocalNotification(
        title: '🎉 ¡Viaje aceptado!',
        body: 'Tu solicitud de viaje fue aceptada',
        payload: json.encode({'tipo': 'ride_accepted_fallback'}),
      );
    }
  }
  
  /// Manejar notificación de viaje rechazado
  static void _handleTripRejectedNotification(dynamic data) {
    try {
      print('🔧 *** PROCESANDO VIAJE RECHAZADO ***: $data');
      
      // Verificar duplicados antes de procesar
      final notificationId = _generateNotificationId(data);
      if (_isNotificationProcessed(notificationId)) {
        return; // Notificación duplicada, no procesar
      }
      
      final notification = data is String ? json.decode(data) : data;
      print('🔧 *** DATOS PARSEADOS VIAJE RECHAZADO ***: $notification');
      
      final nombreEmisor = notification['nombreEmisor'] ?? 'Conductor';
      final origen = notification['origen'] ?? '';
      final destino = notification['destino'] ?? '';
      
      print('🔧 *** MOSTRANDO NOTIFICACIÓN DE VIAJE RECHAZADO por: $nombreEmisor ***');
      
      _showLocalNotification(
        title: '😔 Solicitud rechazada',
        body: '$nombreEmisor rechazó tu solicitud para el viaje de $origen a $destino',
        payload: json.encode({
          'tipo': 'ride_rejected',
          'rutEmisor': notification['rutEmisor'],
          'nombreEmisor': nombreEmisor,
          'origen': origen,
          'destino': destino,
        }),
      );
      
      // Llamar al callback para actualizar la UI del conductor
      _onTripRequestProcessed?.call();
      
      print('✅ *** NOTIFICACIÓN DE VIAJE RECHAZADO PROCESADA CORRECTAMENTE ***');
    } catch (e) {
      print('❌ *** ERROR PROCESANDO VIAJE RECHAZADO ***: $e');
      print('❌ *** DATA RECIBIDA ***: $data');
      
      // Notificación de respaldo
      _showLocalNotification(
        title: '😔 Solicitud rechazada',
        body: 'Tu solicitud de viaje fue rechazada',
        payload: json.encode({'tipo': 'ride_rejected_fallback'}),
      );
    }
  }
  
  /// Manejar notificación de pasajero eliminado del viaje
  static void _handlePassengerRemovedNotification(dynamic data) {
    try {
      print('🚫 *** PROCESANDO PASAJERO ELIMINADO ***: $data');
      
      final notification = data is String ? json.decode(data) : data;
      print('🚫 *** DATOS PARSEADOS PASAJERO ELIMINADO ***: $notification');
      
      final nombreConductor = notification['nombreEmisor'] ?? 'El conductor';
      final origen = notification['origen'] ?? '';
      final destino = notification['destino'] ?? '';
      final reembolsoProcesado = notification['reembolsoProcesado'] ?? false;
      final mensajeDevolucion = notification['mensajeDevolucion'] ?? '';
      
      String bodyMessage;
      if (reembolsoProcesado) {
        bodyMessage = '$nombreConductor te eliminó del viaje de $origen a $destino. $mensajeDevolucion';
      } else {
        bodyMessage = '$nombreConductor te eliminó del viaje de $origen a $destino.';
      }
      
      print('🚫 *** MOSTRANDO NOTIFICACIÓN DE PASAJERO ELIMINADO por: $nombreConductor ***');
      
      // SIEMPRE mostrar diálogo in-app para notificación inmediata (sin verificar duplicados)
      _showInAppDialogNotification(
        '🚫 Eliminado de viaje',
        bodyMessage,
        action: 'passenger_eliminated'
      );
      
      // SIEMPRE mostrar notificación del sistema para eliminación de pasajero (crítica)
      _showLocalNotification(
        title: '🚫 Eliminado de viaje',
        body: bodyMessage,
        payload: json.encode({
          'tipo': 'pasajero_eliminado',
          'rutEmisor': notification['rutEmisor'],
          'nombreEmisor': nombreConductor,
          'origen': origen,
          'destino': destino,
          'reembolsoProcesado': reembolsoProcesado,
          'mensajeDevolucion': mensajeDevolucion,
          'viajeId': notification['viajeId'],
        }),
      );
      
      // Registrar como procesada para evitar procesamiento múltiple de otros aspectos
      final notificationId = _generateNotificationId(data);
      _processedNotifications.add(notificationId);
      
      // Llamar al callback para actualizar la UI si es necesario
      _onTripRequestProcessed?.call();
      
      print('✅ *** NOTIFICACIÓN DE PASAJERO ELIMINADO PROCESADA CORRECTAMENTE ***');
    } catch (e) {
      print('❌ *** ERROR PROCESANDO PASAJERO ELIMINADO ***: $e');
      print('❌ *** DATA RECIBIDA ***: $data');
      
      // Notificación de respaldo
      _showInAppDialogNotification(
        '🚫 Eliminado de viaje',
        'Fuiste eliminado de un viaje',
        action: 'passenger_eliminated'
      );
      
      _showLocalNotification(
        title: '🚫 Eliminado de viaje',
        body: 'Fuiste eliminado de un viaje',
        payload: json.encode({'tipo': 'pasajero_eliminado_fallback'}),
      );
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
  
  /// Callback para mostrar diálogos in-app (debe ser configurado por la aplicación)
  static Function(String title, String message, {String? action})? _showInAppDialog;
  
  /// Configurar callback para mostrar diálogos in-app
  static void setInAppDialogCallback(Function(String title, String message, {String? action}) callback) {
    _showInAppDialog = callback;
    print('✅ Callback de diálogo in-app configurado');
  }
  
  /// Mostrar diálogo in-app si hay callback configurado
  static void _showInAppDialogNotification(String title, String message, {String? action}) {
    if (_showInAppDialog != null) {
      print('🔔 Mostrando diálogo in-app: $title - $message');
      _showInAppDialog!(title, message, action: action);
    } else {
      print('⚠️ No hay callback configurado para diálogos in-app');
    }
  }
  
  /// Mostrar notificación local
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
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
      
      // Determinar si es una solicitud de amistad para agregar botones
      bool esSolicitudAmistad = false;
      try {
        if (payload != null) {
          final data = json.decode(payload);
          esSolicitudAmistad = data['tipo'] == 'solicitud_amistad';
        }
      } catch (e) {
        print('❌ Error parseando payload para determinar tipo: $e');
      }
      
      AndroidNotificationDetails androidNotificationDetails;
      
      if (esSolicitudAmistad) {
        // Notificación con botón "Ver solicitud" únicamente para solicitudes de amistad
        androidNotificationDetails = AndroidNotificationDetails(
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
          autoCancel: false, // No auto-cancelar para que el usuario pueda ver el botón
          ongoing: false,
          silent: false,
          enableLights: true,
          ledColor: Color(0xFF2E7D32),
          ledOnMs: 1000,
          ledOffMs: 500,
          ticker: 'BioRuta',
          actions: [
            AndroidNotificationAction(
              'view_request',
              'Ver solicitud',
              showsUserInterface: true,
              cancelNotification: true, // Cancelar la notificación al presionar
            ),
          ],
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
            case 'solicitud_viaje':
            case 'solicitud_viaje_fallback':
              print('🚗 Tap en notificación de solicitud de viaje');
              final viajeId = data['viajeId'];
              if (viajeId != null) {
                _navigateToTripDetail(viajeId);
              } else {
                print('⚠️ No se encontró viajeId en la notificación');
                _navigateToNotifications();
              }
              break;
            case 'amistad_aceptada':
            case 'amistad_rechazada':
              _navigateToFriends();
              break;
            case 'chat_individual':
              _navigateToChatIndividual(data);
              break;
            case 'chat_grupal':
              _navigateToChatGrupal(data);
            case 'nueva_peticion_soporte':
              print('📱 Tap en notificación de solicitud de soporte');
              _navigateToAdminPanel();
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
  
  /// Navegar al chat individual
  static void _navigateToChatIndividual(Map<String, dynamic> data) {
    try {
      print('🔄 Navegando a chat individual...');
      // final rutEmisor = data['rutEmisor'] ?? '';
      // final nombreEmisor = data['nombreEmisor'] ?? 'Usuario';
      
      // TODO: Implementar navegación al chat individual
      // NavigationService.navigateToChatIndividual(rutEmisor, nombreEmisor);
      
      // Por ahora, navegar a notificaciones como fallback
      _navigateToNotifications();
    } catch (e) {
      print('❌ Error navegando a chat individual: $e');
      _navigateToNotifications();
    }
  }
  
  /// Navegar al chat grupal
  static void _navigateToChatGrupal(Map<String, dynamic> data) {
    try {
      print('🔄 Navegando a chat grupal...');
      // final grupoId = data['grupoId'] ?? '';
      // final nombreGrupo = data['nombreGrupo'] ?? 'Chat Grupal';
      
      // TODO: Implementar navegación al chat grupal
      // NavigationService.navigateToChatGrupal(grupoId, nombreGrupo);
      
      // Por ahora, navegar a notificaciones como fallback
      _navigateToNotifications();
    } catch (e) {
      print('❌ Error navegando a chat grupal: $e');
      _navigateToNotifications();
    }
  }
  
  /// Navegar al panel de administrador
  static void _navigateToAdminPanel() {
    print('🔄 Navegando al panel de administrador...');
    NavigationService.navigateToAdminPanel();
  }

  /// Navegar al detalle del viaje específico
  static void _navigateToTripDetail(String viajeId) {
    print('🔄 Navegando al detalle del viaje: $viajeId');
    NavigationService.navigateToTripDetail(viajeId);
  }
  
  /// Verificar si el servicio está conectado
  static bool get isConnected => _socket?.connected ?? false;
  
  /// Obtener el RUT del usuario actual
  static String? get currentUserRut => _currentUserRut;
  
  /// Manejar notificación de chat individual
  static void _handleChatIndividualNotification(dynamic data) {
    try {
      print('💬 Procesando notificación de chat individual: $data');
      
      // Verificar duplicados antes de procesar
      final notificationId = _generateNotificationId(data);
      if (_isNotificationProcessed(notificationId)) {
        return; // Notificación duplicada, no procesar
      }
      
      final notification = data is String ? json.decode(data) : data;
      
      final nombreEmisor = notification['nombreEmisor'] ?? 'Usuario';
      final mensaje = notification['mensaje'] ?? '';
      final rutEmisor = notification['rutEmisor'] ?? '';
      final chatId = notification['chatId'] ?? '';
      
      // Mostrar notificación con el mensaje
      _showLocalNotification(
        title: '💬 $nombreEmisor',
        body: mensaje.length > 50 ? '${mensaje.substring(0, 50)}...' : mensaje,
        payload: json.encode({
          'tipo': 'chat_individual',
          'rutEmisor': rutEmisor,
          'nombreEmisor': nombreEmisor,
          'chatId': chatId,
        }),
      );
      
      print('✅ Notificación de chat individual procesada correctamente');
    } catch (e) {
      print('❌ Error procesando notificación de chat individual: $e');
    }
  }
  
  /// Manejar notificación de chat grupal
  static void _handleChatGrupalNotification(dynamic data) {
    try {
      print('👥 Procesando notificación de chat grupal: $data');
      
      // Verificar duplicados antes de procesar
      final notificationId = _generateNotificationId(data);
      if (_isNotificationProcessed(notificationId)) {
        return; // Notificación duplicada, no procesar
      }
      
      final notification = data is String ? json.decode(data) : data;
      
      final nombreEmisor = notification['nombreEmisor'] ?? 'Usuario';
      final mensaje = notification['mensaje'] ?? '';
      final rutEmisor = notification['rutEmisor'] ?? '';
      final grupoId = notification['grupoId'] ?? '';
      final nombreGrupo = notification['nombreGrupo'] ?? 'Chat Grupal';
      
      // Mostrar notificación con el mensaje grupal
      _showLocalNotification(
        title: '👥 $nombreGrupo',
        body: '$nombreEmisor: ${mensaje.length > 50 ? '${mensaje.substring(0, 50)}...' : mensaje}',
        payload: json.encode({
          'tipo': 'chat_grupal',
          'rutEmisor': rutEmisor,
          'nombreEmisor': nombreEmisor,
          'grupoId': grupoId,
          'nombreGrupo': nombreGrupo,
        }),
      );
      
      print('✅ Notificación de chat grupal procesada correctamente');
    } catch (e) {
      print('❌ Error procesando notificación de chat grupal: $e');
    }
  }
  
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
  
  /// Manejar notificación de solicitud de soporte (para administradores)
  static void _handleSupportRequestNotification(dynamic data) {
    try {
      print('🆘 *** PROCESANDO SOLICITUD DE SOPORTE ***: $data');
      
      // Verificar duplicados antes de procesar
      final notificationId = _generateNotificationId(data);
      if (_isNotificationProcessed(notificationId)) {
        return; // Notificación duplicada, no procesar
      }
      
      final notification = data is String ? json.decode(data) : data;
      print('🆘 *** DATOS PARSEADOS SOPORTE ***: $notification');
      
      final nombreEmisor = notification['nombreEmisor'] ?? 'Usuario desconocido';
      final rutEmisor = notification['rutEmisor'] ?? '';
      final motivo = notification['motivo'] ?? 'Solicitud de soporte';
      final prioridad = notification['prioridad'] ?? 'media';
      final peticionId = notification['peticionId'] ?? '';
      
      // Emoji basado en prioridad
      String emoji = '🆘';
      switch (prioridad.toLowerCase()) {
        case 'baja':
          emoji = '💬';
          break;
        case 'media':
          emoji = '🆘';
          break;
        case 'alta':
          emoji = '🚨';
          break;
        case 'urgente':
          emoji = '🔥';
          break;
      }
      
      print('🆘 *** MOSTRANDO NOTIFICACIÓN DE SOPORTE ***');
      print('🆘 Emisor: $nombreEmisor (RUT: $rutEmisor)');
      print('🆘 Motivo: $motivo | Prioridad: $prioridad');
      
      _showLocalNotification(
        title: '$emoji Nueva solicitud de soporte',
        body: '$nombreEmisor necesita soporte',
        payload: json.encode({
          'tipo': 'nueva_peticion_soporte',
          'rutEmisor': rutEmisor,
          'nombreEmisor': nombreEmisor,
          'motivo': motivo,
          'prioridad': prioridad,
          'peticionId': peticionId,
        }),
      );
      
      print('✅ Notificación de solicitud de soporte procesada correctamente');
    } catch (e) {
      print('❌ Error procesando solicitud de soporte: $e');
      print('❌ Data recibida: $data');
      
      // Fallback: mostrar notificación genérica
      _showLocalNotification(
        title: '🆘 Nueva solicitud de soporte',
        body: 'Un usuario necesita asistencia de un administrador',
        payload: json.encode({'tipo': 'nueva_peticion_soporte_fallback'}),
      );
    }
  }
}
