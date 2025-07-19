import 'dart:async';
import '../models/chat_grupal_models.dart';
import '../services/chat_grupal_service.dart';
import '../services/socket_service.dart';

class ViajeEstadoService {
  static final ViajeEstadoService _instance = ViajeEstadoService._internal();
  static ViajeEstadoService get instance => _instance;
  
  ViajeEstadoService._internal();

  // --- Controladores de Stream ---
  final StreamController<ChatGrupalInfo> _viajeEstadoController = StreamController<ChatGrupalInfo>.broadcast();
  final StreamController<String> _viajeEventosController = StreamController<String>.broadcast();
  
  // --- Streams públicos ---
  Stream<ChatGrupalInfo> get viajeEstadoStream => _viajeEstadoController.stream;
  Stream<String> get viajeEventosStream => _viajeEventosController.stream;
  
  // --- Variables de estado ---
  ChatGrupalInfo? _viajeActual;
  bool _estaEnChatGrupal = false;
  Timer? _monitoreoTimer;
  bool _isInitialized = false;
  
  // --- Servicios ---
  final SocketService _socketService = SocketService.instance;
  
  // --- Listeners ---
  StreamSubscription? _socketConnectionSubscription;
  
  // Inicializar el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🚗📡 Inicializando ViajeEstadoService...');
      
      // Configurar listeners de socket
      _setupSocketListeners();
      
      // Cargar estado inicial del viaje
      await _cargarEstadoInicial();
      
      // Iniciar monitoreo periódico
      _iniciarMonitoreo();
      
      _isInitialized = true;
      print('🚗✅ ViajeEstadoService inicializado correctamente');
      
    } catch (e) {
      print('🚗❌ Error inicializando ViajeEstadoService: $e');
    }
  }
  
  // Configurar listeners del socket
  void _setupSocketListeners() {
    // Listener para conexión/desconexión
    _socketConnectionSubscription = _socketService.connectionStream.listen((isConnected) {
      if (isConnected) {
        print('🚗📡 Socket conectado, verificando estado del viaje...');
        _verificarEstadoViaje();
      } else {
        print('🚗📡 Socket desconectado');
      }
    });
    
    // Listener para eventos relacionados con viajes
    _socketService.groupChatEventsStream.listen((data) {
      _handleViajeEvent(data);
    });
  }
  
  // Cargar estado inicial del viaje
  Future<void> _cargarEstadoInicial() async {
    try {
      final viajeActivo = await ChatGrupalService.obtenerViajeActivo();
      
      if (viajeActivo.estaActivo) {
        await _procesarViajeActivo(viajeActivo);
      } else {
        _procesarViajeInactivo();
      }
      
    } catch (e) {
      print('🚗❌ Error cargando estado inicial: $e');
    }
  }
  
  // Iniciar monitoreo periódico del estado del viaje
  void _iniciarMonitoreo() {
    _monitoreoTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _verificarEstadoViaje();
    });
  }
  
  // Verificar estado del viaje
  Future<void> _verificarEstadoViaje() async {
    try {
      final viajeActivo = await ChatGrupalService.obtenerViajeActivo();
      
      // Comparar con el estado anterior
      if (_viajeActual?.idViaje != viajeActivo.idViaje || 
          _viajeActual?.estaActivo != viajeActivo.estaActivo) {
        
        if (viajeActivo.estaActivo) {
          await _procesarViajeActivo(viajeActivo);
        } else {
          _procesarViajeInactivo();
        }
      }
      
    } catch (e) {
      print('🚗❌ Error verificando estado del viaje: $e');
    }
  }
  
  // Procesar viaje activo
  Future<void> _procesarViajeActivo(ChatGrupalInfo viaje) async {
    try {
      print('🚗✅ Procesando viaje activo: ${viaje.idViaje}');
      
      // Actualizar estado interno
      _viajeActual = viaje;
      
      // Notificar cambio de estado
      _viajeEstadoController.add(viaje);
      
      // Auto-join al chat grupal si no está ya en el chat
      if (!_estaEnChatGrupal && viaje.usuarioEstaEnChat) {
        await _autoJoinChatGrupal(viaje.idViaje);
      }
      
    } catch (e) {
      print('🚗❌ Error procesando viaje activo: $e');
    }
  }
  
  // Procesar viaje inactivo
  void _procesarViajeInactivo() {
    print('🚗📴 Procesando viaje inactivo');
    
    // Si estaba en un chat grupal, salir
    if (_estaEnChatGrupal && _viajeActual != null) {
      _autoLeaveChatGrupal(_viajeActual!.idViaje);
    }
    
    // Limpiar estado
    _viajeActual = ChatGrupalInfo.empty();
    _estaEnChatGrupal = false;
    
    // Notificar cambio de estado
    _viajeEstadoController.add(_viajeActual!);
  }
  
  // Auto-join al chat grupal
  Future<void> _autoJoinChatGrupal(String idViaje) async {
    try {
      print('🚗🔄 Auto-join al chat grupal: $idViaje');
      
      // Verificar si ya está en el chat
      final estaEnChat = await ChatGrupalService.verificarEstaEnChatGrupal(idViaje);
      
      if (estaEnChat && !_estaEnChatGrupal) {
        // Unirse al chat grupal
        ChatGrupalService.unirseAlChatGrupal(idViaje);
        _estaEnChatGrupal = true;
        
        // Notificar evento
        _viajeEventosController.add('joined_group_chat');
        
        print('🚗✅ Auto-join exitoso al chat grupal');
      }
      
    } catch (e) {
      print('🚗❌ Error en auto-join: $e');
    }
  }
  
  // Auto-leave del chat grupal
  void _autoLeaveChatGrupal(String idViaje) {
    try {
      print('🚗🔄 Auto-leave del chat grupal: $idViaje');
      
      if (_estaEnChatGrupal) {
        // Salir del chat grupal
        ChatGrupalService.salirDelChatGrupal(idViaje);
        _estaEnChatGrupal = false;
        
        // Notificar evento
        _viajeEventosController.add('left_group_chat');
        
        print('🚗✅ Auto-leave exitoso del chat grupal');
      }
      
    } catch (e) {
      print('🚗❌ Error en auto-leave: $e');
    }
  }
  
  // Manejar eventos del viaje
  void _handleViajeEvent(Map<String, dynamic> data) {
    final eventType = data['_eventType'];
    
    switch (eventType) {
      case 'trip_confirmed':
        print('🚗✅ Viaje confirmado, iniciando auto-join...');
        _verificarEstadoViaje();
        break;
        
      case 'trip_cancelled':
        print('🚗❌ Viaje cancelado, iniciando auto-leave...');
        _procesarViajeInactivo();
        _viajeEventosController.add('trip_cancelled');
        break;
        
      case 'trip_finished':
        print('🚗🏁 Viaje finalizado, cerrando chat...');
        _procesarViajeInactivo();
        _viajeEventosController.add('trip_finished');
        break;
        
      case 'passenger_confirmed':
        print('🚗👤 Pasajero confirmado, verificando estado...');
        _verificarEstadoViaje();
        break;
        
      case 'passenger_cancelled':
        print('🚗👤 Pasajero cancelado, verificando estado...');
        _verificarEstadoViaje();
        break;
        
      default:
        print('🚗📡 Evento de viaje no manejado: $eventType');
    }
  }
  
  // Obtener estado actual del viaje
  ChatGrupalInfo? get viajeActual => _viajeActual;
  
  // Verificar si está en chat grupal
  bool get estaEnChatGrupal => _estaEnChatGrupal;
  
  // Forzar actualización del estado
  Future<void> actualizarEstado() async {
    await _verificarEstadoViaje();
  }
  
  // Unirse manualmente al chat grupal
  Future<void> unirseAlChatGrupal(String idViaje) async {
    await _autoJoinChatGrupal(idViaje);
  }
  
  // Salir manualmente del chat grupal
  void salirDelChatGrupal(String idViaje) {
    _autoLeaveChatGrupal(idViaje);
  }
  
  // Limpiar recursos
  void dispose() {
    _monitoreoTimer?.cancel();
    _socketConnectionSubscription?.cancel();
    _viajeEstadoController.close();
    _viajeEventosController.close();
    _isInitialized = false;
    
    print('🚗🧹 ViajeEstadoService limpiado');
  }
}
