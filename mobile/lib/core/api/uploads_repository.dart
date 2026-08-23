import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'api_constants.dart';

final uploadsRepositoryProvider = Provider<UploadsRepository>((ref) {
  return UploadsRepository(ref.read(apiClientProvider).dio);
});

/// Sube imágenes (perfil, moto, portada de ruta) al backend y devuelve la
/// URL relativa que se guarda en el modelo correspondiente. Usado por el
/// diálogo de fin de ruta, el alta de moto y los ajustes de perfil.
class UploadsRepository {
  UploadsRepository(this._dio);

  final Dio _dio;

  Future<String> uploadImage(File file) async {
    final fileName = file.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });
    final response = await _dio.post(ApiConstants.uploadImage, data: formData);
    return response.data['url'] as String;
  }
}
