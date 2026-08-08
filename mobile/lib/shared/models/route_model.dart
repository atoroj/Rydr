import 'package:latlong2/latlong.dart';

class RouteModel {
  final int id;
  final String name;
  final String? description;
  final int authorId;
  final Map<String, dynamic> geojson;
  final double distanceKm;
  final int durationMinutes;
  final DateTime createdAt;
  final int timesRidden;

  const RouteModel({
    required this.id,
    required this.name,
    this.description,
    required this.authorId,
    required this.geojson,
    required this.distanceKm,
    required this.durationMinutes,
    required this.createdAt,
    required this.timesRidden,
  });

  /// Extrae la lista de puntos del GeoJSON LineString para dibujar en el mapa.
  List<LatLng> get path {
    final coords = geojson['coordinates'] as List<dynamic>?;
    if (coords == null) return [];
    return coords.map((c) {
      final point = c as List<dynamic>;
      // GeoJSON orden: [longitud, latitud]
      return LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble());
    }).toList();
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) => RouteModel(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        authorId: json['author_id'] as int,
        geojson: json['geojson'] as Map<String, dynamic>,
        distanceKm: (json['distance_km'] as num).toDouble(),
        durationMinutes: json['duration_minutes'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
        timesRidden: json['times_ridden'] as int,
      );
}
