import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_constants.dart';
import '../../../shared/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider).dio);
});

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;
  final _storage = const FlutterSecureStorage();

  Future<UserModel> login(String email, String password) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );

    final token = response.data['access_token'] as String;
    await _storage.write(key: 'access_token', value: token);

    // El backend no devuelve el usuario en el login, lo buscamos por email
    final userResponse = await _dio.get('${ApiConstants.users}/email/$email');
    final user = UserModel.fromJson(userResponse.data as Map<String, dynamic>);

    // Guardamos id y username para recuperarlos sin red
    await _storage.write(key: 'user_id', value: user.id.toString());
    await _storage.write(key: 'username', value: user.username);
    await _storage.write(key: 'email', value: user.email);

    return user;
  }

  Future<UserModel?> restoreSession() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return null;

    final id = await _storage.read(key: 'user_id');
    final username = await _storage.read(key: 'username');
    final email = await _storage.read(key: 'email');

    if (id == null || username == null || email == null) return null;
    return UserModel(id: int.parse(id), username: username, email: email);
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
