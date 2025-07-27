import 'package:flutter/material.dart';
import '../models/direccion_sugerida.dart';

class BarraBusquedaWidget extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final List<DireccionSugerida> sugerencias;
  final bool mostrandoSugerencias;
  final Function(DireccionSugerida) onSugerenciaTap;

  const BarraBusquedaWidget({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSearch,
    required this.onClear,
    required this.sugerencias,
    required this.mostrandoSugerencias,
    required this.onSugerenciaTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Escribe una dirección o lugar (mín. 4 caracteres)',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onClear,
                      ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: onSearch,
                    ),
                  ],
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        if (mostrandoSugerencias && sugerencias.isNotEmpty)
          Card(
            elevation: 8,
            margin: const EdgeInsets.only(top: 4),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: sugerencias.length,
              itemBuilder: (context, index) {
                String tipoSugerencia = sugerencias[index].esRegional ? "🎯 Regional" : "🌍 General";
                
                return ListTile(
                  title: Text(
                    sugerencias[index].displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Solo mostrar tiempo estimado si es destino (tiempoEstimado > 0)
                      if (sugerencias[index].tiempoEstimado > 0)
                        Text(
                          'Tiempo estimado de viaje: ${sugerencias[index].tiempoEstimado} minutos',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Text(
                        tipoSugerencia,
                        style: TextStyle(
                          color: sugerencias[index].esRegional ? Colors.purple[600] : Colors.blue[600],
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => onSugerenciaTap(sugerencias[index]),
                );
              },
            ),
          ),
      ],
    );
  }
}
