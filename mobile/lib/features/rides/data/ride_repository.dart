import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_constants.dart';
import '../../../shared/models/ride_model.dart';

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepository(ref.read(apiClientProvider).dio);
});

class RideRepository {
  RideRepository(this._dio);

  final Dio _dio;

  Future<RideModel> startRide({
    required int riderId,
    required int motorbikeId,
  }) async {
    final response = await _dio.post(ApiConstants.rides, data: {
      'rider_id': riderId,
      'motorbike_id': motorbikeId,
    });
    return RideModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RideModel> finishRide(int rideId) async {
    final response = await _dio.patch('${ApiConstants.rides}/$rideId/finish');
    return RideModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> addTrackPoint({
    required int rideId,
    required double latitude,
    required double longitude,
    double? altitude,
    double? speed,
    required DateTime timestamp,
  }) async {
    await _dio.post('${ApiConstants.rides}/$rideId/track-points', data: {
      'latitude': latitude,
      'longitude': longitude,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
      'timestamp': timestamp.toIso8601String(),
    });
  }

  Future<List<RideModel>> getRidesByRider(int riderId) async {
    final response = await _dio.get('${ApiConstants.rides}/rider/$riderId');
    return (response.data as List<dynamic>)
        .map((json) => RideModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<RideModel> getRideById(int rideId) async {
    final response = await _dio.get('${ApiConstants.rides}/$rideId');
    return RideModel.fromJson(response.data as Map<String, dynamic>);
  }
}
