import 'package:flutter/material.dart';

class PaginaIndividual extends StatelessWidget {
  // Recibimos el nombre del amigo a través del constructor
  final String nombre;

  // Constructor para inicializar el nombre del amigo
  const PaginaIndividual({Key? key, required this.nombre}) : super(key: key);

  // Función para obtener la hora de conexión (puedes reemplazarla por una real)
  String getHoraConexion() {
    final now = DateTime.now();
    return "${now.hour}:${now.minute < 10 ? '0' : ''}${now.minute}"; // Formato HH:mm
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 70,
        titleSpacing: 0,
        leading: InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.arrow_back,
                size: 24,
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.brown,
              ),
            ],
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Alinea todo a la izquierda
          children: [
            Text(
              '$nombre', // Nombre del amigo
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold, // Nombre en negrita
              ),
            ),
            SizedBox(height: 4), // Espacio entre el nombre y la hora
            Text(
              'Última conexión: ${getHoraConexion()}', // Hora de conexión
              style: TextStyle(
                fontSize: 14, // Más pequeño para que sea como un subtítulo
                color: Colors.grey, // Color gris para hacerlo sutil
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Text('Aquí va el contenido del chat con $nombre'),
      ),
    );
  }
}
