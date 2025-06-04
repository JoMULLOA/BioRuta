class DireccionSugerida {
  final String displayName;
  final double lat;
  final double lon;
  double distancia;
  bool esRegional;

  DireccionSugerida({
    required this.displayName,
    required this.lat,
    required this.lon,
    this.distancia = 0.0,
    this.esRegional = false,
  });

  factory DireccionSugerida.fromJson(Map<String, dynamic> json, {bool esRegional = false}) {
    return DireccionSugerida(
      displayName: json['display_name'],
      lat: double.parse(json['lat']),
      lon: double.parse(json['lon']),
      esRegional: esRegional,
    );
  }
}
