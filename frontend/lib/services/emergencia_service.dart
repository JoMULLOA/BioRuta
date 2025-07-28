import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../models/contacto_emergencia.dart';
import '../utils/token_manager.dart';
import '../config/confGlobal.dart';

class EmergenciaService {
  static const String _tutorialKey = 'tutorial_sos_completado';
  static String get _baseUrl => '${confGlobal.baseUrl}/contactos-emergencia';
  static const String _trackingKey = 'ubicacion_tracking_activo';
  static const String _trackingStartTimeKey = 'tracking_start_time';
  
  // Singleton pattern
  static final EmergenciaService _instance = EmergenciaService._internal();
  factory EmergenciaService() => _instance;
  EmergenciaService._internal();

  // Timer para tracking de ubicación
  Timer? _trackingTimer;
  static const Duration _trackingDuration = Duration(hours: 8);
  static const Duration _updateInterval = Duration(minutes: 30);

  // Obtener headers con token de autenticación
  Future<Map<String, String>> _getHeaders() async {
    final headers = await TokenManager.getAuthHeaders();
    return headers ?? {
      'Content-Type': 'application/json',
    };
  }

  // Obtener contactos de emergencia del servidor
  Future<List<ContactoEmergencia>> obtenerContactos() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> contactosList = data['data'] ?? [];
        final contactos = contactosList.map((json) => ContactoEmergencia.fromJson(json)).toList();
        
        // Siempre sincronizar con almacenamiento local
        await _guardarContactosLocales(contactos);
        
        return contactos;
      } else {
        debugPrint('Error al obtener contactos del servidor: ${response.statusCode}');
        // Fallback a SharedPreferences si el servidor no está disponible
        return await _obtenerContactosLocales();
      }
    } catch (e) {
      debugPrint('Error al obtener contactos del servidor: $e');
      // Fallback a SharedPreferences
      return await _obtenerContactosLocales();
    }
  }

  // Obtener contactos locales (fallback)
  Future<List<ContactoEmergencia>> _obtenerContactosLocales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactosJson = prefs.getString('contactos_emergencia');
      
      if (contactosJson == null) return [];
      
      final List<dynamic> contactosList = json.decode(contactosJson);
      return contactosList.map((json) => ContactoEmergencia.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error al obtener contactos locales: $e');
      return [];
    }
  }

  // Guardar contactos localmente (sincronización)
  Future<bool> _guardarContactosLocales(List<ContactoEmergencia> contactos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactosJson = json.encode(contactos.map((c) => c.toJson()).toList());
      return await prefs.setString('contactos_emergencia', contactosJson);
    } catch (e) {
      debugPrint('Error al guardar contactos locales: $e');
      return false;
    }
  }

  // Agregar contacto de emergencia
  Future<bool> agregarContacto(ContactoEmergencia contacto) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: json.encode({
          'nombre': contacto.nombre,
          'telefono': contacto.telefono,
          'email': contacto.email,
        }),
      );

      if (response.statusCode == 201) {
        // Forzar actualización desde servidor después de crear
        await Future.delayed(const Duration(milliseconds: 500)); // Pequeña pausa para asegurar consistencia
        final contactosActualizados = await obtenerContactos();
        await _guardarContactosLocales(contactosActualizados);
        
        debugPrint('✅ Contacto creado y sincronizado exitosamente');
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al agregar contacto');
      }
    } catch (e) {
      debugPrint('Error al agregar contacto: $e');
      rethrow;
    }
  }

  // Actualizar contacto de emergencia
  Future<bool> actualizarContacto(ContactoEmergencia contacto) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/${contacto.id}'),
        headers: headers,
        body: json.encode({
          'nombre': contacto.nombre,
          'telefono': contacto.telefono,
          'email': contacto.email,
        }),
      );

      if (response.statusCode == 200) {
        // Sincronizar contactos locales
        final contactos = await obtenerContactos();
        await _guardarContactosLocales(contactos);
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al actualizar contacto');
      }
    } catch (e) {
      debugPrint('Error al actualizar contacto: $e');
      rethrow;
    }
  }

  // Eliminar contacto de emergencia
  Future<bool> eliminarContacto(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Sincronizar contactos locales
        final contactos = await obtenerContactos();
        await _guardarContactosLocales(contactos);
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al eliminar contacto');
      }
    } catch (e) {
      debugPrint('Error al eliminar contacto: $e');
      return false;
    }
  }

  // Verificar si el tutorial fue completado
  Future<bool> tutorialCompletado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialKey) ?? false;
  }

  // Marcar tutorial como completado
  Future<void> marcarTutorialCompletado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialKey, true);
  }

  // Obtener ubicación actual
  Future<Position?> obtenerUbicacionActual() async {
    try {
      // Verificar permisos de ubicación
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Los servicios de ubicación están deshabilitados');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permisos de ubicación denegados permanentemente');
      }

      // Obtener ubicación actual
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Error al obtener ubicación: $e');
      return null;
    }
  }

  // Activar emergencia - enviar mensajes a los contactos con tracking opcional
  Future<bool> activarEmergencia(String nombreUsuario, {bool conTracking = true, Map<String, dynamic>? infoAdicional}) async {
    try {
      final contactos = await obtenerContactos();
      
      if (contactos.isEmpty) {
        throw Exception('No tienes contactos de emergencia configurados');
      }

      if (conTracking) {
        // Usar el nuevo sistema con tracking de 8 horas
        return await iniciarTrackingUbicacion(nombreUsuario, infoAdicional: infoAdicional);
      } else {
        // Usar el sistema tradicional de emergencia (una sola vez)
        return await _activarEmergenciaTradicional(nombreUsuario, infoAdicional: infoAdicional);
      }
    } catch (e) {
      debugPrint('Error al activar emergencia: $e');
      rethrow;
    }
  }

  // Método tradicional de emergencia (para compatibilidad)
  Future<bool> _activarEmergenciaTradicional(String nombreUsuario, {Map<String, dynamic>? infoAdicional}) async {
    try {
      final contactos = await obtenerContactos();
      final posicion = await obtenerUbicacionActual();
      String ubicacionTexto = '';
      
      if (posicion != null) {
        ubicacionTexto = 'Mi ubicación actual: https://maps.google.com/?q=${posicion.latitude},${posicion.longitude}';
      } else {
        ubicacionTexto = 'No se pudo obtener la ubicación actual';
      }

      // Construir información del viaje si está disponible
      String infoViajeTexto = '';
      debugPrint('🔍 Verificando infoAdicional: $infoAdicional');
      if (infoAdicional != null && infoAdicional['viaje'] != null) {
        final viaje = infoAdicional['viaje'];
        debugPrint('📋 Datos del viaje recibidos: $viaje');
        infoViajeTexto = '''

📋 INFORMACIÓN DEL VIAJE:
• Conductor: ${viaje['nombreConductor'] ?? 'No disponible'}
• RUT Conductor: ${viaje['rutConductor'] ?? 'No disponible'}
• Vehículo: ${viaje['patente'] ?? 'No disponible'}
• Origen: ${viaje['origen'] ?? 'No disponible'}
• Destino: ${viaje['destino'] ?? 'No disponible'}
        ''';
        debugPrint('✅ Información del viaje agregada al mensaje');
      } else {
        debugPrint('⚠️ No se recibió información del viaje');
      }

      // Mensaje de emergencia
      final mensaje = '''
🚨 ALERTA DE EMERGENCIA 🚨

$nombreUsuario ha activado el botón de emergencia en BioRuta.

$ubicacionTexto$infoViajeTexto

Por favor, contacta inmediatamente o verifica el estado de $nombreUsuario.

Mensaje enviado automáticamente desde BioRuta - App de viajes compartidos.
      ''';

      debugPrint('📱 [EMERGENCIA] Mensaje final a enviar:');
      debugPrint('----------------------------------------');
      debugPrint(mensaje);
      debugPrint('----------------------------------------');

      // Enviar mensaje a cada contacto vía WhatsApp
      bool algunoEnviado = false;
      for (final contacto in contactos) {
        debugPrint('📞 Enviando mensaje a: ${contacto.telefono}');
        final exito = await enviarWhatsApp(contacto.telefono, mensaje);
        if (exito) algunoEnviado = true;
      }

      if (!algunoEnviado) {
        throw Exception('No se pudo enviar el mensaje a ningún contacto');
      }

      return true;
    } catch (e) {
      debugPrint('Error al activar emergencia tradicional: $e');
      rethrow;
    }
  }

  // Enviar mensaje por WhatsApp
  Future<bool> enviarWhatsApp(String telefono, String mensaje) async {
    try {
      // Limpiar el número de teléfono (quitar espacios, guiones, etc.)
      String numeroLimpio = telefono.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Asegurarse de que el número tenga código de país
      if (!numeroLimpio.startsWith('+')) {
        // Asumir código de país Chile (+56) si no está especificado
        if (numeroLimpio.startsWith('9')) {
          numeroLimpio = '+56$numeroLimpio';
        } else {
          numeroLimpio = '+$numeroLimpio';
        }
      }

      // Codificar el mensaje para URL
      final mensajeCodificado = Uri.encodeComponent(mensaje);
      
      // Crear URL de WhatsApp
      final url = 'https://wa.me/$numeroLimpio?text=$mensajeCodificado';
      final uri = Uri.parse(url);

      // Intentar abrir WhatsApp
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('No se puede abrir WhatsApp para el número: $telefono');
        return false;
      }
    } catch (e) {
      debugPrint('Error al enviar WhatsApp a $telefono: $e');
      return false;
    }
  }

  // Validar número de teléfono chileno (+569XXXXXXXX)
  bool validarTelefono(String telefono) {
    final numeroLimpio = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    // Debe tener formato +569XXXXXXXX (12 dígitos totales)
    return RegExp(r'^\+569\d{8}$').hasMatch(numeroLimpio);
  }

  // Formatear número de teléfono para mostrar
  String formatearTelefono(String telefono) {
    final numeroLimpio = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (numeroLimpio.startsWith('+56') && numeroLimpio.length == 12) {
      // Formato chileno: +56 9 1234 5678
      return '+56 ${numeroLimpio.substring(3, 4)} ${numeroLimpio.substring(4, 8)} ${numeroLimpio.substring(8)}';
    }
    
    return numeroLimpio;
  }

  // =========== FUNCIONALIDAD DE TRACKING EN TIEMPO REAL (8 HORAS) ===========
  
  // Iniciar tracking de ubicación en tiempo real por 8 horas
  Future<bool> iniciarTrackingUbicacion(String nombreUsuario, {Map<String, dynamic>? infoAdicional}) async {
    try {
      // Verificar si ya hay un tracking activo
      if (await _estaTrackingActivo()) {
        debugPrint('Tracking de ubicación ya está activo');
        return true;
      }

      final contactos = await obtenerContactos();
      if (contactos.isEmpty) {
        throw Exception('No tienes contactos de emergencia configurados');
      }

      // Obtener ubicación inicial
      final posicion = await obtenerUbicacionActual();
      if (posicion == null) {
        throw Exception('No se pudo obtener la ubicación actual');
      }

      // Enviar ubicación inicial con Live Location de WhatsApp
      await _enviarUbicacionInicial(nombreUsuario, posicion, contactos, infoAdicional: infoAdicional);

      // Marcar tracking como activo
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_trackingKey, true);
      await prefs.setInt(_trackingStartTimeKey, DateTime.now().millisecondsSinceEpoch);

      // Iniciar timer para actualizaciones periódicas
      _iniciarTimerTracking(nombreUsuario);

      return true;
    } catch (e) {
      debugPrint('Error al iniciar tracking: $e');
      rethrow;
    }
  }

  // Verificar si el tracking está activo
  Future<bool> _estaTrackingActivo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activo = prefs.getBool(_trackingKey) ?? false;
      
      if (!activo) return false;

      // Verificar si han pasado las 8 horas
      final startTime = prefs.getInt(_trackingStartTimeKey);
      if (startTime == null) return false;

      final fechaInicio = DateTime.fromMillisecondsSinceEpoch(startTime);
      final tiempoTranscurrido = DateTime.now().difference(fechaInicio);

      if (tiempoTranscurrido >= _trackingDuration) {
        // El tracking ha expirado, detenerlo
        await detenerTracking();
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error verificando tracking: $e');
      return false;
    }
  }

  // Enviar ubicación inicial con WhatsApp Live Location
  Future<void> _enviarUbicacionInicial(String nombreUsuario, Position posicion, List<ContactoEmergencia> contactos, {Map<String, dynamic>? infoAdicional}) async {
    // Construir información del viaje si está disponible
    String infoViajeTexto = '';
    debugPrint('🔍 [TRACKING] Verificando infoAdicional: $infoAdicional');
    if (infoAdicional != null && infoAdicional['viaje'] != null) {
      final viaje = infoAdicional['viaje'];
      debugPrint('📋 [TRACKING] Datos del viaje recibidos: $viaje');
      infoViajeTexto = '''

📋 INFORMACIÓN DEL VIAJE:
• Conductor: ${viaje['nombreConductor'] ?? 'No disponible'}
• RUT Conductor: ${viaje['rutConductor'] ?? 'No disponible'}
• Vehículo: ${viaje['patente'] ?? 'No disponible'}
• Origen: ${viaje['origen'] ?? 'No disponible'}
• Destino: ${viaje['destino'] ?? 'No disponible'}
      ''';
      debugPrint('✅ [TRACKING] Información del viaje agregada al mensaje');
    } else {
      debugPrint('⚠️ [TRACKING] No se recibió información del viaje');
    }

    final mensaje = '''
🚨 EMERGENCIA ACTIVADA 🚨

$nombreUsuario ha activado el sistema de emergencia SOS.

📍 UBICACIÓN EN TIEMPO REAL:

Ubicación actual: https://maps.google.com/?q=${posicion.latitude},${posicion.longitude}$infoViajeTexto

⚠️ IMPORTANTE: Este es un mensaje de emergencia rapido enviado por $nombreUsuario. Por favor contacta inmediatamente a $nombreUsuario.

Mensaje enviado desde BioRuta - App de viajes compartidos.
    ''';

    debugPrint('📱 [TRACKING] Mensaje final a enviar:');
    debugPrint('----------------------------------------');
    debugPrint(mensaje);
    debugPrint('----------------------------------------');

    // Enviar a cada contacto
    for (final contacto in contactos) {
      debugPrint('📞 [TRACKING] Enviando mensaje a: ${contacto.telefono}');
      await enviarWhatsApp(contacto.telefono, mensaje);
      
      // Pequeña pausa entre envíos para evitar spam
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // Iniciar timer para tracking periódico
  void _iniciarTimerTracking(String nombreUsuario) {
    _trackingTimer?.cancel();
    
    _trackingTimer = Timer.periodic(_updateInterval, (timer) async {
      try {
        final activo = await _estaTrackingActivo();
        if (!activo) {
          timer.cancel();
          return;
        }

        await _enviarActualizacionUbicacion(nombreUsuario);
      } catch (e) {
        debugPrint('Error en actualización de tracking: $e');
      }
    });
  }

  // Enviar actualización de ubicación
  Future<void> _enviarActualizacionUbicacion(String nombreUsuario) async {
    try {
      final contactos = await obtenerContactos();
      if (contactos.isEmpty) return;

      final posicion = await obtenerUbicacionActual();
      if (posicion == null) {
        debugPrint('No se pudo obtener ubicación para actualización');
        return;
      }

      // Calcular tiempo transcurrido
      final prefs = await SharedPreferences.getInstance();
      final startTime = prefs.getInt(_trackingStartTimeKey);
      if (startTime == null) return;

      final fechaInicio = DateTime.fromMillisecondsSinceEpoch(startTime);
      final tiempoTranscurrido = DateTime.now().difference(fechaInicio);
      final horasTranscurridas = tiempoTranscurrido.inHours;
      final minutosTranscurridos = tiempoTranscurrido.inMinutes % 60;

      final mensaje = '''
📍 ACTUALIZACIÓN DE UBICACIÓN - SOS

$nombreUsuario - Actualización automática
Tiempo transcurrido: ${horasTranscurridas}h ${minutosTranscurridos}m

Nueva ubicación: https://maps.google.com/?q=${posicion.latitude},${posicion.longitude}

La ubicación se seguirá compartiendo automáticamente hasta completar 8 horas.

BioRuta - Sistema de Emergencia
      ''';

      // Enviar a cada contacto
      for (final contacto in contactos) {
        await enviarWhatsApp(contacto.telefono, mensaje);
        await Future.delayed(const Duration(seconds: 1));
      }

      debugPrint('Actualización de ubicación enviada exitosamente');
    } catch (e) {
      debugPrint('Error enviando actualización de ubicación: $e');
    }
  }

  // Detener tracking de ubicación
  Future<void> detenerTracking() async {
    try {
      _trackingTimer?.cancel();
      _trackingTimer = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_trackingKey);
      await prefs.remove(_trackingStartTimeKey);

      // Enviar mensaje de finalización
      await _enviarMensajeFinalizacion();
    } catch (e) {
      debugPrint('Error deteniendo tracking: $e');
    }
  }

  // Enviar mensaje de finalización de tracking
  Future<void> _enviarMensajeFinalizacion() async {
    try {
      final contactos = await obtenerContactos();
      if (contactos.isEmpty) return;

      final mensaje = '''
✅ TRACKING DE EMERGENCIA FINALIZADO

El sistema de emergencia a finalizado.

Si aún necesitas asistencia, por favor contacta directamente.

BioRuta - Sistema de Emergencia
      ''';

      for (final contacto in contactos) {
        await enviarWhatsApp(contacto.telefono, mensaje);
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      debugPrint('Error enviando mensaje de finalización: $e');
    }
  }

  // Obtener estado del tracking
  Future<Map<String, dynamic>> obtenerEstadoTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activo = prefs.getBool(_trackingKey) ?? false;
      
      if (!activo) {
        return {
          'activo': false,
          'tiempoRestante': 0,
          'tiempoTranscurrido': 0,
        };
      }

      final startTime = prefs.getInt(_trackingStartTimeKey);
      if (startTime == null) {
        return {
          'activo': false,
          'tiempoRestante': 0,
          'tiempoTranscurrido': 0,
        };
      }

      final fechaInicio = DateTime.fromMillisecondsSinceEpoch(startTime);
      final tiempoTranscurrido = DateTime.now().difference(fechaInicio);
      final tiempoRestante = _trackingDuration - tiempoTranscurrido;

      return {
        'activo': tiempoRestante.inMilliseconds > 0,
        'tiempoRestante': tiempoRestante.inMilliseconds > 0 ? tiempoRestante.inMinutes : 0,
        'tiempoTranscurrido': tiempoTranscurrido.inMinutes,
        'horasRestantes': tiempoRestante.inHours,
        'minutosRestantes': tiempoRestante.inMinutes % 60,
      };
    } catch (e) {
      debugPrint('Error obteniendo estado de tracking: $e');
      return {
        'activo': false,
        'tiempoRestante': 0,
        'tiempoTranscurrido': 0,
      };
    }
  }

  // Reiniciar servicio de tracking (para después de restart de app)
  Future<void> reiniciarServicioTracking(String nombreUsuario) async {
    final estado = await obtenerEstadoTracking();
    if (estado['activo'] == true) {
      _iniciarTimerTracking(nombreUsuario);
      debugPrint('Servicio de tracking reiniciado exitosamente');
    }
  }

  // Método estático para mostrar diálogo de confirmación de emergencia desde cualquier pantalla
  static Future<void> mostrarDialogoEmergenciaGlobal(BuildContext context, {Map<String, dynamic>? infoViaje}) async {
    if (!context.mounted) return;

    final emergenciaService = EmergenciaService();
    
    try {
      // Verificar si hay contactos configurados
      final contactos = await emergenciaService.obtenerContactos();
      
      if (contactos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes contactos de emergencia configurados. Ve a la pantalla SOS para configurarlos.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Mostrar diálogo de confirmación
      final confirmar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: const Color(0xFF854937), size: 28),
                const SizedBox(width: 8),
                const Text('⚠️ Activar Emergencia'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Estás seguro que quieres activar el modo de emergencia?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF854937).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF854937).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Se enviará un mensaje de emergencia a:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF854937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...contactos.map((contacto) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 16, color: const Color(0xFF854937)),
                            const SizedBox(width: 4),
                            Text(
                              '${contacto.nombre} (${contacto.telefono})',
                              style: TextStyle(color: const Color(0xFF6B3B2D)),
                            ),
                          ],
                        ),
                      )).toList(),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF854937),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sí, activar'),
              ),
            ],
          );
        },
      );

      if (confirmar != true) return;

      // Activar emergencia
      const nombreUsuario = 'Usuario BioRuta';
      
      Map<String, dynamic>? infoAdicional;
      if (infoViaje != null) {
        infoAdicional = {
          'viaje': infoViaje,
        };
      }

      await emergenciaService.activarEmergencia(
        nombreUsuario,
        conTracking: false, // Solo enviar una vez
        infoAdicional: infoAdicional,
      );

      // Mostrar confirmación de éxito
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text('Emergencia Activada'),
              ],
            ),
            content: const Text(
              '¡Alerta de emergencia enviada! '
              'Tus contactos han recibido tu ubicación por WhatsApp.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF854937),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al activar emergencia: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
