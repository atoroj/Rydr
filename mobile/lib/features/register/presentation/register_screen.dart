import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// 'geolocator' y 'mapbox_maps_flutter' exportan cada uno su propio
// `Position`/`LocationSettings`; usamos prefijo en geolocator (el paquete
// con menos usos aquí) para evitar la colisión de nombres.
import 'package:geolocator/geolocator.dart' as geo;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
// 'ImageSource' también existe en mapbox_maps_flutter (fuente de un raster
// layer) — la ocultamos de aquí para que gane la de image_picker, que es la
// que usamos en este archivo (foto de portada de la ruta).
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide ImageSource;
import '../../rides/presentation/ride_provider.dart';
import '../../motorbikes/presentation/motorbikes_provider.dart';
import '../../routes/data/route_repository.dart';
import '../../../core/api/uploads_repository.dart';
import '../../../shared/models/motorbike_model.dart';
import '../../../shared/models/ride_model.dart';

/// Pantalla "Registrar": se abre desde el botón central de la bottom bar.
/// Mapa a pantalla completa + Iniciar/Pausar/Finalizar. El estado de
/// grabación vive en [rideProvider] (Riverpod global, no atado a esta
/// pantalla), así que salir de aquí mientras se graba no interrumpe el
/// tracking en curso.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _polylineManager;
  PolylineAnnotation? _routeAnnotation;
  StreamSubscription<geo.Position>? _positionSub;

  LatLng? _currentPosition;
  double _lastHeading = 0.0;

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // Puck de posición nativo de Mapbox.
    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        puckBearing: PuckBearing.HEADING,
        pulsingEnabled: true,
      ),
    );

    _polylineManager = await map.annotations.createPolylineAnnotationManager();

    if (_currentPosition != null) {
      await _flyTo(_currentPosition!, zoom: 15);
    }
    await _updateRoutePolyline(ref.read(rideProvider).path);
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) return;
    }
    if (permission == geo.LocationPermission.deniedForever) return;

    final pos = await geo.Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
      await _flyTo(_currentPosition!, zoom: 15.0);
    }

    // Vista local del puck mientras se navega esta pantalla (independiente
    // del stream de grabación en background que lleva rideProvider).
    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((geo.Position newPos) async {
      if (!mounted) return;
      final newLatLng = LatLng(newPos.latitude, newPos.longitude);

      // Filtro anti-trompicones: solo recalculamos la dirección si te has
      // movido más de 2 metros.
      if (_currentPosition != null) {
        final distance = const Distance().distance(_currentPosition!, newLatLng);
        if (distance > 2.0) {
          _lastHeading = const Distance().bearing(_currentPosition!, newLatLng);
        }
      }

      setState(() => _currentPosition = newLatLng);

      if (ref.read(rideProvider).isRecording && !ref.read(rideProvider).isPaused) {
        await _mapboxMap?.easeTo(
          CameraOptions(
            center: Point(coordinates: Position(newLatLng.longitude, newLatLng.latitude)),
            zoom: 17.0,
            bearing: _lastHeading,
          ),
          MapAnimationOptions(duration: 400),
        );
      }
    });
  }

  Future<void> _flyTo(LatLng target, {required double zoom}) async {
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(target.longitude, target.latitude)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  /// Dibuja/actualiza la polyline del track del ride activo sobre el mapa.
  Future<void> _updateRoutePolyline(List<LatLng> path) async {
    final manager = _polylineManager;
    if (manager == null) return;

    if (path.length < 2) {
      if (_routeAnnotation != null) {
        await manager.delete(_routeAnnotation!);
        _routeAnnotation = null;
      }
      return;
    }

    final coordinates = path.map((p) => Position(p.longitude, p.latitude)).toList();
    final color = Theme.of(context).colorScheme.primary.toARGB32();

    if (_routeAnnotation == null) {
      _routeAnnotation = await manager.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coordinates),
          lineColor: color,
          lineWidth: 4,
        ),
      );
    } else {
      _routeAnnotation!.geometry = LineString(coordinates: coordinates);
      await manager.update(_routeAnnotation!);
    }
  }

  Future<void> _onStartPressed() async {
    await _showSelectMotorbikeDialog();
  }

  Future<void> _onFinishPressed() async {
    // 1. Finalizamos la ruta
    await ref.read(rideProvider.notifier).finishRide();

    // 2. Animamos la cámara de vuelta al inicio
    if (_currentPosition != null) {
      await _mapboxMap?.easeTo(
        CameraOptions(
          center: Point(
            coordinates: Position(_currentPosition!.longitude, _currentPosition!.latitude),
          ),
          zoom: 15.0,
          bearing: 0.0,
        ),
        MapAnimationOptions(duration: 600),
      );
    }

    // 3. Tras finalizar, ofrecer publicar la ruta si hay puntos grabados
    final finished = ref.read(rideProvider).ride;
    if (finished != null &&
        !finished.isActive &&
        finished.trackPoints.isNotEmpty &&
        mounted) {
      await _showPublishRideDialog(finished);
    }
  }

  /// Muestra el diálogo para publicar el ride recién finalizado como ruta pública.
  Future<void> _showPublishRideDialog(RideModel ride) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PublishRideDialog(ride: ride),
    );
  }

  Future<void> _showSelectMotorbikeDialog() async {
    final motorbikes = ref.read(motorbikesProvider).value ?? [];

    if (motorbikes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade una moto antes de iniciar una ruta')),
      );
      return;
    }

    final selected = await showDialog<MotorbikeModel>(
      context: context,
      builder: (ctx) => _SelectMotorbikeDialog(motorbikes: motorbikes),
    );

    if (selected != null) {
      await ref.read(rideProvider.notifier).startRide(selected.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reacciona a cambios del ride activo actualizando la polyline de forma
    // imperativa, sin reconstruir el MapWidget (perdería el estado del mapa).
    ref.listen<ActiveRideState>(rideProvider, (previous, next) {
      _updateRoutePolyline(next.path);
    });

    final rideState = ref.watch(rideProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ── Mapa a pantalla completa ─────────────────────────────────────
          MapWidget(
            styleUri: MapboxStyles.OUTDOORS,
            onMapCreated: _onMapCreated,
          ),

          // ── Botón volver ──────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
          ),

          // ── HUD del ride activo ───────────────────────────────────────────
          if (rideState.isRecording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 72,
              right: 16,
              child: _RideHud(rideState: rideState),
            ),

          // ── Botón centrar en posición actual ─────────────────────────────
          Positioned(
            right: 16,
            bottom: rideState.isRecording ? 160 : 100,
            child: FloatingActionButton.small(
              heroTag: 'center',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              onPressed: () {
                if (_currentPosition != null) {
                  _flyTo(_currentPosition!, zoom: 15.0);
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // ── Controles grandes: Iniciar / Pausar-Reanudar / Finalizar ──────
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _RecordingControls(
              rideState: rideState,
              onStart: _onStartPressed,
              onPause: () => ref.read(rideProvider.notifier).pauseRide(),
              onResume: () => ref.read(rideProvider.notifier).resumeRide(),
              onFinish: _onFinishPressed,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Controles de grabación ────────────────────────────────────────────────────

/// Botonera grande (pensada para pulsarse con guantes) que cambia según el
/// estado del ride: Iniciar → Pausar/Finalizar (o Reanudar/Finalizar).
class _RecordingControls extends StatelessWidget {
  const _RecordingControls({
    required this.rideState,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
  });

  final ActiveRideState rideState;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    if (rideState.isSaving) {
      return const FilledButton(
        onPressed: null,
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    if (!rideState.isRecording) {
      return FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar ruta'),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: rideState.isPaused ? onResume : onPause,
            icon: Icon(rideState.isPaused ? Icons.play_arrow : Icons.pause),
            label: Text(rideState.isPaused ? 'Reanudar' : 'Pausar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: onFinish,
            icon: const Icon(Icons.stop),
            label: const Text('Finalizar'),
          ),
        ),
      ],
    );
  }
}

class _RideHud extends StatelessWidget {
  const _RideHud({required this.rideState});
  final ActiveRideState rideState;

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(rideState.ride!.startedAt);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours.toString().padLeft(2, '0');

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _HudItem(
              icon: Icons.timer,
              label: 'Tiempo',
              value: '$hours:$minutes',
            ),
            _HudItem(
              icon: Icons.route,
              label: 'Puntos',
              value: '${rideState.path.length}',
            ),
            if (rideState.isPaused)
              const _HudItem(
                icon: Icons.pause_circle_outline,
                label: 'Estado',
                value: 'Pausado',
              ),
          ],
        ),
      ),
    );
  }
}

class _HudItem extends StatelessWidget {
  const _HudItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

// ── Diálogo publicar ride como ruta ──────────────────────────────────────────

/// Formulario que aparece al finalizar un ride para publicarlo como ruta pública.
class _PublishRideDialog extends ConsumerStatefulWidget {
  const _PublishRideDialog({required this.ride});
  final RideModel ride;

  @override
  ConsumerState<_PublishRideDialog> createState() =>
      _PublishRideDialogState();
}

class _PublishRideDialogState extends ConsumerState<_PublishRideDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _publishing = false;
  File? _coverPhoto;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _coverPhoto = File(picked.path));
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _publishing = true);

    try {
      String? coverImageUrl;
      if (_coverPhoto != null) {
        coverImageUrl =
            await ref.read(uploadsRepositoryProvider).uploadImage(_coverPhoto!);
      }
      await ref.read(routeRepositoryProvider).createRouteFromRide(
            rideId: widget.ride.id,
            name: _nameController.text.trim(),
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            coverImageUrl: coverImageUrl,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Ruta publicada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _publishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al publicar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¡Ruta completada!'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.ride.trackPoints.length} puntos GPS grabados',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text('¿Quieres publicarla para otros moteros?'),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickCoverPhoto,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: _coverPhoto == null
                      ? Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 28),
                              SizedBox(height: 4),
                              Text('Foto de portada (opcional)'),
                            ],
                          ),
                        )
                      : Image.file(_coverPhoto!, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la ruta *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _publishing ? null : () => Navigator.pop(context),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: _publishing ? null : _publish,
          child: _publishing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Publicar'),
        ),
      ],
    );
  }
}

class _SelectMotorbikeDialog extends StatelessWidget {
  const _SelectMotorbikeDialog({required this.motorbikes});
  final List<MotorbikeModel> motorbikes;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Con qué moto sales?'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: motorbikes.length,
          itemBuilder: (_, i) => ListTile(
            leading: const Icon(Icons.two_wheeler),
            title: Text(motorbikes[i].displayName),
            subtitle: Text('${motorbikes[i].cc} cc'),
            onTap: () => Navigator.pop(context, motorbikes[i]),
          ),
        ),
      ),
    );
  }
}
