import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../data/ride_repository.dart';
import '../../../features/auth/presentation/auth_provider.dart';
import '../../../shared/models/ride_model.dart';

// ─── Ajustes de localización con soporte de segundo plano ────────────────────

/// Configuración de posición usada mientras se graba un ride: en Android
/// levanta un foreground service (obligatorio desde Android 10+ para poder
/// seguir leyendo el GPS con la app minimizada); en iOS activa las
/// actualizaciones en background del `CLLocationManager`. Los permisos
/// nativos correspondientes ya están declarados en AndroidManifest.xml e
/// Info.plist — aquí solo se activan desde el lado Dart.
LocationSettings _recordingLocationSettings() {
  const accuracy = LocationAccuracy.bestForNavigation;
  const distanceFilter = 10; // metros

  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Rydr',
        notificationText: 'Grabando tu ruta…',
        enableWakeLock: true,
      ),
    );
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return AppleSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
  }
  return const LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
}

/// Pide permiso "Siempre" (Always/Background). Si el usuario solo concede
/// "mientras se usa" no bloqueamos el ride: se graba igual, pero solo con
/// la app en primer plano — mejor eso que no grabar nada.
Future<void> _requestBackgroundPermission() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.whileInUse) {
    // En Android/iOS recientes esto reabre el diálogo del sistema para
    // subir de "mientras se usa" a "siempre" cuando el SO lo permite.
    await Geolocator.requestPermission();
  }
}

// ─── Estado del ride activo ───────────────────────────────────────────────────

class ActiveRideState {
  final RideModel? ride; // null = sin ride activo
  final List<LatLng> path; // puntos acumulados para dibujar en el mapa
  final bool isSaving; // true mientras se está guardando/finalizando
  final bool isPaused; // true mientras la grabación está en pausa

  const ActiveRideState({
    this.ride,
    this.path = const [],
    this.isSaving = false,
    this.isPaused = false,
  });

  bool get isRecording => ride != null && ride!.isActive;

  ActiveRideState copyWith({
    RideModel? ride,
    List<LatLng>? path,
    bool? isSaving,
    bool? isPaused,
  }) =>
      ActiveRideState(
        ride: ride ?? this.ride,
        path: path ?? this.path,
        isSaving: isSaving ?? this.isSaving,
        isPaused: isPaused ?? this.isPaused,
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
    await _requestBackgroundPermission();

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
      locationSettings: _recordingLocationSettings(),
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

  /// Pausa la grabación sin finalizar el ride: cancela el stream de GPS
  /// (y con él, en Android, el foreground service) hasta que se reanude.
  Future<void> pauseRide() async {
    if (!state.isRecording || state.isPaused) return;
    await _gpsSub?.cancel();
    _gpsSub = null;
    state = state.copyWith(isPaused: true);
  }

  /// Reanuda la grabación tras una pausa, sobre el mismo ride.
  void resumeRide() {
    if (!state.isRecording || !state.isPaused) return;
    state = state.copyWith(isPaused: false);
    _startGpsTracking(state.ride!.id);
  }

  Future<void> finishRide() async {
    if (state.ride == null) return;
    state = state.copyWith(isSaving: true);

    await _gpsSub?.cancel();
    _gpsSub = null;

    final repo = ref.read(rideRepositoryProvider);
    final finished = await repo.finishRide(state.ride!.id);

    state = state.copyWith(ride: finished, isSaving: false, isPaused: false);
  }
}
