import 'package:url_launcher/url_launcher.dart';

class MapLauncher {
  static Future<void> openRouteInGoogleMaps(double oLat, double oLng, double dLat, double dLng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$oLat,$oLng&destination=$dLat,$dLng&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }

  static Future<void> openRouteInWaze(double dLat, double dLng) async {
    final uri = Uri.parse('https://waze.com/ul?ll=$dLat,$dLng&navigate=yes');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }
}
