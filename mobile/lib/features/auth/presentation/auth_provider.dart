import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../shared/models/user_model.dart';

/// Estado global de autenticación.
///
/// - AsyncLoading  → comprobando sesión guardada al arrancar
/// - AsyncData(UserModel) → sesión activa
/// - AsyncData(null) → no autenticado
/// - AsyncError → error en login
final authProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    // Al arrancar la app, intenta restaurar la sesión del almacenamiento seguro
    final repo = ref.read(authRepositoryProvider);
    return repo.restoreSession();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      return repo.login(email, password);
    });
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncData(null);
  }
}
