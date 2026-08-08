import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../data/ride_repository.dart';
import '../../../features/auth/presentation/auth_provider.dart';
import '../../../shared/models/ride_model.dart';

// ─── Stream de posición GPS (activo solo cuando hay una ruta en curso) ───────

final gpsPositionProvider = StreamProvider<Position>((ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // enviar punto cada 10 metros de desplazamiento
    ),
  );
});

// ─── Estado del ride activo ───────────────────────────────────────────────────

class ActiveRideState {
  final RideModel? ride;         // null = sin ride activo
  final List<LatLng> path;       // puntos acumulados para dibujar en el mapa
  final bool isSaving;           // true mientras se está guardando/finalizando

  const ActiveRideState({
    this.ride,
    this.path = const [],
    this.isSaving = false,
  });

  bool get isRecording => ride != null && ride!.isActive;

  ActiveRideState copyWith({
    RideModel? ride,
    List<LatLng>? path,
    bool? isSaving,
  }) =>
      ActiveRideState(
        ride: ride ?? this.ride,
        path: path ?? this.path,
        isSaving: isSaving ?? this.isSaving,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

final rideProvider =
    NotifierProvider<RideNotifier, ActiveRideState>(RideNotifier.new);

class RideNotifier extends Notifier<ActiveRideState> {
  StreamSubscription<Position>? _gpsSub;

  @override
  ActiveRideState build() {
    ref.onDispose(() => _gpsSub?.cancel());
    return const ActiveRideState();
  }

  Future<void> startRide(int motorbikeId) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    state = state.copyWith(isSaving: true);

    final repo = ref.read(rideRepositoryProvider);
    final ride = await repo.startRide(
      riderId: user.id,
      motorbikeId: motorbikeId,
    );

    state = ActiveRideState(ride: ride, path: const [], isSaving: false);
    _startGpsTracking(ride.id);
  }

  void _startGpsTracking(int rideId) {
    final repo = ref.read(rideRepositoryProvider);

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) async {
      // Actualiza el path visible en el mapa
      final newPoint = LatLng(position.latitude, position.longitude);
      state = state.copyWith(path: [...state.path, newPoint]);

      // Envía el track point a la API
      await repo.addTrackPoint(
        rideId: rideId,
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        speed: position.speed >= 0 ? position.speed * 3.6 : null, // m/s → km/h
        timestamp: position.timestamp,
      );
    });
  }

  Future<void> finishRide() async {
    if (state.ride == null) return;
    state = state.copyWith(isSaving: true);

    await _gpsSub?.cancel();
    _gpsSub = null;

    final repo = ref.read(rideRepositoryProvider);
    final finished = await repo.finishRide(state.ride!.id);

    state = state.copyWith(ride: finished, isSaving: false);
  }

}
