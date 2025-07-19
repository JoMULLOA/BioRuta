import 'package:flutter/material.dart';

class VehiculoIconHelper {
  
  /// Obtiene el ícono del vehículo basado en la marca y modelo
  static IconData obtenerIconoVehiculo(String? marca, String? modelo) {
    if (marca == null || modelo == null) {
      return Icons.directions_car;
    }
    
    final marcaLower = marca.toLowerCase();
    final modeloLower = modelo.toLowerCase();
    
    // Determinar tipo de vehículo por marca y modelo
    if (_esSUV(marcaLower, modeloLower)) {
      return Icons.directions_car_filled;
    } else if (_esSedan(marcaLower, modeloLower)) {
      return Icons.directions_car;
    } else if (_esHatchback(marcaLower, modeloLower)) {
      return Icons.directions_car_outlined;
    } else if (_esCamioneta(marcaLower, modeloLower)) {
      return Icons.local_shipping;
    } else {
      return Icons.directions_car;
    }
  }
  
  /// Obtiene el color del ícono basado en la marca
  static Color obtenerColorIcono(String? marca) {
    if (marca == null) return Colors.blue;
    
    final marcaLower = marca.toLowerCase();
    
    switch (marcaLower) {
      case 'toyota':
        return Colors.red;
      case 'ford':
        return Colors.blue;
      case 'chevrolet':
        return Colors.yellow[700]!;
      case 'hyundai':
        return Colors.grey[400]!;
      case 'nissan':
        return Colors.grey[600]!;
      case 'honda':
        return Colors.red[800]!;
      case 'volkswagen':
        return Colors.blue[800]!;
      case 'mazda':
        return Colors.red[600]!;
      case 'suzuki':
        return Colors.blue[600]!;
      case 'mitsubishi':
        return Colors.red[900]!;
      case 'kia':
        return Colors.green[700]!;
      case 'peugeot':
        return Colors.blue[900]!;
      case 'renault':
        return Colors.yellow[800]!;
      case 'subaru':
        return Colors.blue[700]!;
      default:
        return Colors.blue;
    }
  }
  
  /// Obtiene el tipo de vehículo como string
  static String obtenerTipoVehiculo(String? marca, String? modelo) {
    if (marca == null || modelo == null) {
      return 'Auto';
    }
    
    final marcaLower = marca.toLowerCase();
    final modeloLower = modelo.toLowerCase();
    
    if (_esSUV(marcaLower, modeloLower)) {
      return 'SUV';
    } else if (_esSedan(marcaLower, modeloLower)) {
      return 'Sedán';
    } else if (_esHatchback(marcaLower, modeloLower)) {
      return 'Hatchback';
    } else if (_esCamioneta(marcaLower, modeloLower)) {
      return 'Camioneta';
    } else {
      return 'Auto';
    }
  }
  
  /// Crea un widget de ícono personalizado para el mapa
  static Widget crearIconoVehiculoMapa({
    required String? marca,
    required String? modelo,
    double size = 24.0,
    bool conFondo = true,
  }) {
    final icono = obtenerIconoVehiculo(marca, modelo);
    final color = obtenerColorIcono(marca);
    
    if (conFondo) {
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Icon(
          icono,
          color: color,
          size: size,
        ),
      );
    } else {
      return Icon(
        icono,
        color: color,
        size: size,
      );
    }
  }
  
  /// Crea un widget de información del vehículo
  static Widget crearInfoVehiculo({
    required String? marca,
    required String? modelo,
    required String? color,
    required String? patente,
    TextStyle? estiloTexto,
  }) {
    final tipo = obtenerTipoVehiculo(marca, modelo);
    
    return Row(
      children: [
        crearIconoVehiculoMapa(
          marca: marca,
          modelo: modelo,
          size: 32,
          conFondo: false,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${marca ?? 'N/A'} ${modelo ?? 'N/A'}',
                style: estiloTexto?.copyWith(fontWeight: FontWeight.bold) ??
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '$tipo • ${color ?? 'N/A'} • ${patente ?? 'N/A'}',
                style: estiloTexto?.copyWith(color: Colors.grey[600]) ??
                    TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Métodos privados para identificar tipos de vehículos
  
  static bool _esSUV(String marca, String modelo) {
    // SUVs comunes en Chile
    final suvModelos = [
      'rav4', 'crv', 'cr-v', 'tucson', 'sportage', 'santa fe', 'sorento',
      'x-trail', 'qashqai', 'outlander', 'asx', 'vitara', 'grand vitara',
      'forester', 'xv', 'ecosport', 'kuga', 'escape', 'edge', 'territory',
      'captiva', 'tracker', 'equinox', 'traverse', 'tahoe', 'suburban',
      'pilot', 'passport', 'ridgeline', 'pathfinder', 'armada', 'murano',
      'suv', 'crossover'
    ];
    
    return suvModelos.any((suv) => modelo.contains(suv));
  }
  
  static bool _esSedan(String marca, String modelo) {
    // Sedanes comunes en Chile
    final sedanModelos = [
      'corolla', 'camry', 'prius', 'yaris sedan', 'avensis',
      'focus sedan', 'mondeo', 'fiesta sedan',
      'cruze', 'sonic', 'malibu', 'impala',
      'elantra', 'sonata', 'accent', 'azera',
      'sentra', 'altima', 'maxima', 'versa',
      'civic', 'accord', 'city',
      'jetta', 'passat', 'vento',
      'lancer', 'galant',
      'rio', 'cerato', 'optima',
      'sedan'
    ];
    
    return sedanModelos.any((sedan) => modelo.contains(sedan));
  }
  
  static bool _esHatchback(String marca, String modelo) {
    // Hatchbacks comunes en Chile
    final hatchModelos = [
      'yaris', 'corolla hatchback', 'auris', 'etios',
      'fiesta', 'focus hatchback', 'ka',
      'aveo', 'spark', 'onix',
      'i10', 'i20', 'i30', 'getz',
      'march', 'note', 'tiida',
      'fit', 'jazz', 'civic hatchback',
      'gol', 'polo', 'golf',
      'mirage', 'colt',
      'picanto', 'rio hatchback',
      'swift', 'baleno', 'celerio',
      'hatchback', 'hatch'
    ];
    
    return hatchModelos.any((hatch) => modelo.contains(hatch));
  }
  
  static bool _esCamioneta(String marca, String modelo) {
    // Camionetas comunes en Chile
    final camionetaModelos = [
      'hilux', 'tacoma', 'tundra',
      'ranger', 'f-150', 'f-250', 'f-350',
      'silverado', 'colorado', 's10',
      'frontier', 'navara', 'titan',
      'ridgeline',
      'l200', 'triton',
      'dmax', 'd-max',
      'amarok',
      'camioneta', 'pickup', 'truck'
    ];
    
    return camionetaModelos.any((camioneta) => modelo.contains(camioneta));
  }
}
