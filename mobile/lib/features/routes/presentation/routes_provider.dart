import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/route_repository.dart';
import '../../../shared/models/route_model.dart';

final routesProvider =
    AsyncNotifierProvider<RoutesNotifier, List<RouteModel>>(RoutesNotifier.new);

class RoutesNotifier extends AsyncNotifier<List<RouteModel>> {
  @override
  Future<List<RouteModel>> build() {
    return ref.read(routeRepositoryProvider).getPublicRoutes();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(routeRepositoryProvider).getPublicRoutes(),
    );
  }

  Future<void> markAsRidden(int routeId) async {
    await ref.read(routeRepositoryProvider).markAsRidden(routeId);
    // Recargamos para actualizar el contador times_ridden
    await refresh();
  }
}
