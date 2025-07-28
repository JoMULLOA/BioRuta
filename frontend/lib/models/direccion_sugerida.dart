class DireccionSugerida {
  final String displayName;
  final double lat;
  final double lon;
  double distancia;
  int tiempoEstimado; // Tiempo estimado en minutos
  bool esRegional;
  bool? esOrigen; // true si es origen, false si es destino, null si no se especifica

  DireccionSugerida({
    required this.displayName,
    required this.lat,
    required this.lon,
    this.distancia = 0.0,
    this.tiempoEstimado = 0,
    this.esRegional = false,
    this.esOrigen,
  });
  factory DireccionSugerida.fromJson(Map<String, dynamic> json, {bool esRegional = false, bool? esOrigen}) {
    return DireccionSugerida(
      displayName: json['display_name'],
      lat: double.parse(json['lat']),
      lon: double.parse(json['lon']),
      esRegional: esRegional,
      esOrigen: esOrigen,
    );
  }
}
