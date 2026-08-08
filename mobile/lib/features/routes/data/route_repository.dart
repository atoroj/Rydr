import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_constants.dart';
import '../../../shared/models/route_model.dart';

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepository(ref.read(apiClientProvider).dio);
});

class RouteRepository {
  RouteRepository(this._dio);

  final Dio _dio;

  Future<List<RouteModel>> getPublicRoutes() async {
    final response = await _dio.get(ApiConstants.routes);
    return (response.data as List<dynamic>)
        .map((json) => RouteModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<RouteModel> getRouteById(int routeId) async {
    final response = await _dio.get('${ApiConstants.routes}/$routeId');
    return RouteModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RouteModel> createRouteFromRide({
    required int rideId,
    required String name,
    String? description,
  }) async {
    final response = await _dio.post('${ApiConstants.routes}/from-ride', data: {
      'ride_id': rideId,
      'name': name,
      if (description != null) 'description': description,
    });
    return RouteModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> markAsRidden(int routeId) async {
    await _dio.post('${ApiConstants.routes}/$routeId/ride');
  }
}
