import 'package:flutter/material.dart';
import '../models/chat_grupal_models.dart';
import '../services/chat_grupal_service.dart';

class ParticipantesHeaderWidget extends StatelessWidget {
  final List<ParticipanteChat> participantes;
  final String? userRut;

  const ParticipantesHeaderWidget({
    Key? key,
    required this.participantes,
    this.userRut,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (participantes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F2EF),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Text(
            'Participantes (${participantes.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B3B2D),
            ),
          ),
          const SizedBox(height: 8),
          
          // Lista horizontal de participantes
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: participantes.length,
              itemBuilder: (context, index) {
                final participante = participantes[index];
                return _buildParticipantCard(participante);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(ParticipanteChat participante) {
    final colorParticipante = Color(
      ChatGrupalService.obtenerColorParticipante(participante.rut),
    );
    
    final esUsuarioActual = participante.rut == userRut;
    
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          // Avatar con indicador de conexión
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorParticipante,
                  shape: BoxShape.circle,
                  border: esUsuarioActual
                      ? Border.all(
                          color: const Color(0xFF8D4F3A),
                          width: 2,
                        )
                      : null,
                ),
                child: Center(
                  child: Text(
                    participante.iniciales,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              
              // Indicador de conexión
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: participante.estaConectado ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
              
              // Indicador de conductor
              if (participante.esConductor)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD2691E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.drive_eta,
                      color: Colors.white,
                      size: 8,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          // Nombre del participante
          SizedBox(
            width: 60,
            child: Text(
              esUsuarioActual ? 'Tú' : _truncateName(participante.nombre),
              style: TextStyle(
                fontSize: 11,
                fontWeight: esUsuarioActual ? FontWeight.bold : FontWeight.normal,
                color: esUsuarioActual 
                    ? const Color(0xFF6B3B2D)
                    : Colors.black87,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _truncateName(String nombre) {
    if (nombre.length <= 8) return nombre;
    
    // Si tiene más de 8 caracteres, intentar usar solo el primer nombre
    final nombres = nombre.split(' ');
    if (nombres.isNotEmpty && nombres[0].length <= 8) {
      return nombres[0];
    }
    
    // Si el primer nombre es muy largo, truncar
    return '${nombre.substring(0, 6)}...';
  }
}
