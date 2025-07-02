// pagina_individual.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/mensaje_model.dart';
import '../config/confGlobal.dart'; // ¡Importa tu clase de configuración global!

class PaginaIndividual extends StatefulWidget {
  final String nombre;
  final String rutAmigo;
  final String rutUsuarioAutenticado;

  const PaginaIndividual({
    Key? key,
    required this.nombre,
    required this.rutAmigo,
    required this.rutUsuarioAutenticado,
  }) : super(key: key);

  @override
  _PaginaIndividualState createState() => _PaginaIndividualState();
}

class _PaginaIndividualState extends State<PaginaIndividual> {
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  
  String? _jwtToken;

  // ¡Elimina la declaración _baseUrl aquí! Ahora se usa confGlobal.baseUrl

  @override
  void initState() {
    super.initState();
    print('DEBUG PaginaIndividual: RUT del usuario autenticado: ${widget.rutUsuarioAutenticado}');
    print('DEBUG PaginaIndividual: RUT del amigo: ${widget.rutAmigo}');

    _loadTokenAndFetchMessages();
  }

  Future<void> _fetchMessages() async {
    if (_jwtToken == null) {
      print('ERROR: No hay token JWT para obtener mensajes históricos.');
      return;
    }

    try {
      // Usando confGlobal.baseUrl directamente
      final Uri requestUri = Uri.parse('${confGlobal.baseUrl}/chat/conversacion/${widget.rutAmigo}');
      print('DEBUG: Intentando GET historial de mensajes de: $requestUri');

      final response = await http.get(
        requestUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_jwtToken',
        },
      );

      print('DEBUG: Código de estado del historial: ${response.statusCode}');
      print('DEBUG: Cuerpo de la respuesta del historial: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        final List<dynamic> messagesJson = responseData;

        setState(() {
          _messages.clear();
          _messages.addAll(messagesJson.map((json) {
            return Message(
              senderRut: json['emisor']['rut'],
              text: json['contenido'],
              timestamp: DateTime.parse(json['fecha']),
            );
          }).toList());

          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
        print('✅ Historial de mensajes cargado correctamente: ${_messages.length} mensajes.');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });

      } else {
        print('ERROR: Fallo al obtener historial: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar historial: ${response.body}')),
        );
      }
    } catch (e) {
      print('ERROR: Excepción al obtener historial de mensajes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión al cargar historial: $e')),
      );
    }
  }

  Future<void> _loadTokenAndFetchMessages() async {
    _jwtToken = await _storage.read(key: 'jwt_token');
    print('DEBUG PaginaIndividual: Token cargado para envíos y lectura: ${_jwtToken != null ? _jwtToken!.substring(0, _jwtToken!.length > 10 ? 10 : _jwtToken!.length) : "Nulo"}...');
    
    if (_jwtToken != null) {
      await _fetchMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se pudo cargar el token de autenticación.')),
      );
    }
  }


  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final String messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(Message(
        senderRut: widget.rutUsuarioAutenticado,
        text: messageText,
        timestamp: DateTime.now(),
      ));
    });

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    if (_jwtToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró token de autenticación para enviar el mensaje.')),
      );
      print('ERROR: Intento de enviar mensaje sin token.');
      return;
    }

    try {
      // Usando confGlobal.baseUrl directamente
      final response = await http.post(
        Uri.parse('${confGlobal.baseUrl}/chat/mensaje'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_jwtToken',
        },
        body: jsonEncode({
          'contenido': messageText,
          'rutReceptor': widget.rutAmigo,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Mensaje enviado al backend correctamente.');
      } else {
        print('❌ Error al enviar mensaje al backend: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar mensaje: ${response.body}')),
        );
      }
    } catch (e) {
      print('❌ Error de conexión al enviar mensaje: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión al enviar mensaje: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color principal = const Color(0xFF6B3B2D);
    final Color secundario = const Color(0xFF8D4F3A);
    final Color miBurbuja = const Color(0xFFE0F7FA);
    final Color amigoBurbuja = const Color(0xFFDCF8C6);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombre, style: TextStyle(color: principal)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: principal),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final bool isMe = message.senderRut == widget.rutUsuarioAutenticado;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isMe ? amigoBurbuja : miBurbuja,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12.0),
                        topRight: Radius.circular(12.0),
                        bottomLeft: isMe ? Radius.circular(12.0) : Radius.circular(0.0),
                        bottomRight: isMe ? Radius.circular(0.0) : Radius.circular(12.0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: TextStyle(
                            color: isMe ? Colors.black87 : Colors.black87,
                            fontSize: 16.0,
                          ),
                        ),
                        SizedBox(height: 4.0),
                        Text(
                          '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 10.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    ),
                    onSubmitted: (text) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8.0),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: principal,
                  child: Icon(Icons.send, color: Colors.white),
                  elevation: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}