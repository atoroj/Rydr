import 'package:latlong2/latlong.dart';

class TrackPointModel {
  final int id;
  final int rideId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final DateTime timestamp;

  const TrackPointModel({
    required this.id,
    required this.rideId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    required this.timestamp,
  });

  factory TrackPointModel.fromJson(Map<String, dynamic> json) => TrackPointModel(
        id: json['id'] as int,
        rideId: json['ride_id'] as int,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        altitude: (json['altitude'] as num?)?.toDouble(),
        speed: (json['speed'] as num?)?.toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  LatLng get latLng => LatLng(latitude, longitude);
}

class RideModel {
  final int id;
  final int riderId;
  final int motorbikeId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final bool isPublic;
  final List<TrackPointModel> trackPoints;

  const RideModel({
    required this.id,
    required this.riderId,
    required this.motorbikeId,
    required this.startedAt,
    this.finishedAt,
    required this.isPublic,
    this.trackPoints = const [],
  });

  bool get isActive => finishedAt == null;

  List<LatLng> get path => trackPoints.map((tp) => tp.latLng).toList();

  factory RideModel.fromJson(Map<String, dynamic> json) => RideModel(
        id: json['id'] as int,
        riderId: json['rider_id'] as int,
        motorbikeId: json['motorbike_id'] as int,
        startedAt: DateTime.parse(json['started_at'] as String),
        finishedAt: json['finished_at'] != null
            ? DateTime.parse(json['finished_at'] as String)
            : null,
        isPublic: json['is_public'] as bool,
        trackPoints: (json['track_points'] as List<dynamic>?)
                ?.map((tp) => TrackPointModel.fromJson(tp as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
