import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/motorbike_repository.dart';
import '../../../features/auth/presentation/auth_provider.dart';
import '../../../shared/models/motorbike_model.dart';

/// Lista de motos del usuario autenticado
final motorbikesProvider =
    AsyncNotifierProvider<MotorbikesNotifier, List<MotorbikeModel>>(
        MotorbikesNotifier.new);

class MotorbikesNotifier extends AsyncNotifier<List<MotorbikeModel>> {
  @override
  Future<List<MotorbikeModel>> build() async {
    final user = ref.watch(authProvider).value;
    if (user == null) return [];
    return ref.read(motorbikeRepositoryProvider).getMotorbikesByUser(user.id);
  }

  Future<void> addMotorbike({
    required String type,
    required String brand,
    required String model,
    required int cc,
    String? alias,
  }) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(motorbikeRepositoryProvider).createMotorbike(
            userId: user.id,
            type: type,
            brand: brand,
            model: model,
            cc: cc,
            alias: alias,
          );
      return ref
          .read(motorbikeRepositoryProvider)
          .getMotorbikesByUser(user.id);
    });
  }
}
