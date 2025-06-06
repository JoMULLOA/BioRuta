import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? socket;

  // Conectar al servidor WebSocket
  void connect() {
    socket = IO.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket!.connect();

    socket!.on('receive_message', (data) {
      print('Mensaje recibido: $data');
      // Aquí manejarás el mensaje recibido
    });
  }

  // Enviar mensaje al servidor
  void sendMessage(String sender, String text) {
    socket!.emit('send_message', {'sender': sender, 'message': text});
  }

  // Desconectar del socket
  void disconnect() {
    socket!.disconnect();
  }
}