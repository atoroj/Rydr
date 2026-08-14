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
    String? photoUrl,
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
            photoUrl: photoUrl,
          );
      return ref
          .read(motorbikeRepositoryProvider)
          .getMotorbikesByUser(user.id);
    });
  }

  /// Marca [motorbikeId] como la moto actual (garaje virtual): la que
  /// aparece en el perfil social y en el listado de Riders.
  Future<void> setCurrent(int motorbikeId) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(motorbikeRepositoryProvider).setCurrent(motorbikeId);
      return ref
          .read(motorbikeRepositoryProvider)
          .getMotorbikesByUser(user.id);
    });
  }
}
