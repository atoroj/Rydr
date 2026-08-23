import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_constants.dart';
import '../../../shared/models/motorbike_model.dart';

final motorbikeRepositoryProvider = Provider<MotorbikeRepository>((ref) {
  return MotorbikeRepository(ref.read(apiClientProvider).dio);
});

class MotorbikeRepository {
  MotorbikeRepository(this._dio);

  final Dio _dio;

  Future<List<MotorbikeModel>> getMotorbikesByUser(int userId) async {
    final response = await _dio.get('${ApiConstants.motorbikes}/user/$userId');
    return (response.data as List<dynamic>)
        .map((json) => MotorbikeModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<MotorbikeModel> createMotorbike({
    required int userId,
    required String type,
    required String brand,
    required String model,
    required int cc,
    String? alias,
    String? photoUrl,
  }) async {
    final response = await _dio.post(ApiConstants.motorbikes, data: {
      'user_id': userId,
      'type': type,
      'brand': brand,
      'model': model,
      'cc': cc,
      if (alias != null) 'alias': alias,
      if (photoUrl != null) 'photo_url': photoUrl,
    });
    return MotorbikeModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MotorbikeModel> setCurrent(int motorbikeId) async {
    final response =
        await _dio.post('${ApiConstants.motorbikes}/$motorbikeId/set-current');
    return MotorbikeModel.fromJson(response.data as Map<String, dynamic>);
  }
}
