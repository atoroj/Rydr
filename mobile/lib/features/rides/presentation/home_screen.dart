import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'ride_provider.dart';
import '../../motorbikes/presentation/motorbikes_provider.dart';
import '../../routes/data/route_repository.dart';
import '../../../shared/models/motorbike_model.dart';
import '../../../shared/models/ride_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _mapController = MapController();
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
      _mapController.move(_currentPosition!, 15);
    }
  }

  void _onFabPressed(ActiveRideState rideState) async {
    if (rideState.isRecording) {
      await ref.read(rideProvider.notifier).finishRide();
      // Tras finalizar, ofrecer publicar la ruta si hay puntos grabados
      final finished = ref.read(rideProvider).ride;
      if (finished != null &&
          !finished.isActive &&
          finished.trackPoints.isNotEmpty &&
          mounted) {
        await _showPublishRideDialog(finished);
      }
    } else {
      await _showSelectMotorbikeDialog();
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
    final rideState = ref.watch(rideProvider);
    final defaultCenter = _currentPosition ?? const LatLng(40.4168, -3.7038);

    return Scaffold(
      body: Stack(
        children: [
          // ── Mapa ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: defaultCenter,
              initialZoom: 15,
            ),
            children: [
              // Tiles OpenStreetMap (sin API key)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rydr.rydr',
              ),

              // Track del ride activo
              if (rideState.path.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: rideState.path,
                      strokeWidth: 4,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),

              // Posición actual
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── HUD del ride activo ───────────────────────────────────────────
          if (rideState.isRecording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: _RideHud(rideState: rideState),
            ),

          // ── Botón centrar en posición actual ─────────────────────────────
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton.small(
              heroTag: 'center',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, 15);
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),

      // ── FAB: Iniciar / Finalizar ruta ─────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: rideState.isSaving
            ? null
            : () => _onFabPressed(rideState),
        backgroundColor: rideState.isRecording
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        icon: rideState.isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Icon(rideState.isRecording ? Icons.stop : Icons.play_arrow),
        label: Text(rideState.isRecording ? 'Finalizar ruta' : 'Iniciar ruta'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Componentes auxiliares ────────────────────────────────────────────────────

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

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _publishing = true);

    try {
      await ref.read(routeRepositoryProvider).createRouteFromRide(
            rideId: widget.ride.id,
            name: _nameController.text.trim(),
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
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
