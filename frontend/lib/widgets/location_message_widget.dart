import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';

class LocationMessageWidget extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String senderName;
  final DateTime timestamp;
  final bool isOwnMessage;

  const LocationMessageWidget({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.senderName,
    required this.timestamp,
    required this.isOwnMessage,
  }) : super(key: key);

  Future<void> _openInMaps() async {
    final url = LocationService.generateGoogleMapsUrl(latitude, longitude);
    
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        print('❌ No se puede abrir la URL de Maps: $url');
      }
    } catch (e) {
      print('❌ Error abriendo Maps: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinates = LocationService.formatCoordinates(latitude, longitude);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isOwnMessage ? const Color(0xFF854937) : Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono y título
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: isOwnMessage ? Colors.white : const Color(0xFF854937),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOwnMessage ? 'Tu ubicación' : 'Ubicación de $senderName',
                        style: TextStyle(
                          color: isOwnMessage ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Coordenadas
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOwnMessage ? Colors.white.withOpacity(0.2) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coordenadas:',
                        style: TextStyle(
                          color: isOwnMessage ? Colors.white70 : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        coordinates,
                        style: TextStyle(
                          color: isOwnMessage ? Colors.white : Colors.black87,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Botón para abrir en Maps
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openInMaps,
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text('Abrir en Maps'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOwnMessage ? Colors.white : const Color(0xFF854937),
                      foregroundColor: isOwnMessage ? const Color(0xFF854937) : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // Timestamp
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    color: isOwnMessage ? Colors.white70 : Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
