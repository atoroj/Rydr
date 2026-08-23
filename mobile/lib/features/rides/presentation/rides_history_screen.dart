import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ride_repository.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../routes/data/route_repository.dart';
import '../../../shared/models/ride_model.dart';

// ─── Provider del historial de rides del usuario autenticado ─────────────────

final ridesHistoryProvider =
    AsyncNotifierProvider<RidesHistoryNotifier, List<RideModel>>(
        RidesHistoryNotifier.new);

/// Notifier que carga y refresca el historial de rides del rider autenticado.
class RidesHistoryNotifier extends AsyncNotifier<List<RideModel>> {
  @override
  Future<List<RideModel>> build() async {
    final user = ref.watch(authProvider).value;
    if (user == null) return [];
    return ref.read(rideRepositoryProvider).getRidesByRider(user.id);
  }

  /// Recarga la lista desde la API.
  Future<void> refresh() async {
    state = const AsyncLoading();
    final user = ref.read(authProvider).value;
    if (user == null) {
      state = const AsyncData([]);
      return;
    }
    state = await AsyncValue.guard(
      () => ref.read(rideRepositoryProvider).getRidesByRider(user.id),
    );
  }
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────

/// Listado de todos los rides del rider con opción de publicar como ruta pública.
class RidesHistoryScreen extends ConsumerWidget {
  const RidesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(ridesHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis rides'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(ridesHistoryProvider.notifier).refresh(),
          ),
        ],
      ),
      body: ridesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text('Error al cargar: $e'),
              TextButton(
                onPressed: () =>
                    ref.read(ridesHistoryProvider.notifier).refresh(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (rides) {
          if (rides.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aún no tienes rides',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('¡Inicia tu primera ruta desde el mapa!',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Ordenar por fecha descendente
          final sorted = [...rides]
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) =>
                _RideTile(ride: sorted[i]),
          );
        },
      ),
    );
  }
}

// ─── Tile individual de un ride ───────────────────────────────────────────────

class _RideTile extends ConsumerWidget {
  const _RideTile({required this.ride});
  final RideModel ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = ride.finishedAt?.difference(ride.startedAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fecha y estado ───────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  _formatDate(ride.startedAt),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Chip(
                  label: Text(
                    ride.isActive ? 'En curso' : 'Finalizado',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: ride.isActive
                      ? Colors.green.shade100
                      : Colors.grey.shade200,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Métricas ─────────────────────────────────────────────────
            Row(
              children: [
                _Metric(
                  icon: Icons.timer_outlined,
                  label: duration != null
                      ? _formatDuration(duration)
                      : '—',
                ),
                const SizedBox(width: 16),
                _Metric(
                  icon: Icons.location_on_outlined,
                  label: '${ride.trackPoints.length} puntos',
                ),
              ],
            ),

            // ── Botón publicar como ruta ─────────────────────────────────
            if (!ride.isActive && ride.trackPoints.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.public, size: 18),
                  label: const Text('Publicar como ruta'),
                  onPressed: () =>
                      _showPublishDialog(context, ref, ride),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Formatea una fecha en "DD/MM/YYYY HH:mm".
  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  /// Formatea una duración en "Xh Ym" o "Ym Zs".
  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  }

  /// Muestra el diálogo para nombrar y publicar el ride como ruta pública.
  Future<void> _showPublishDialog(
      BuildContext context, WidgetRef ref, RideModel ride) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PublishRideDialog(ride: ride),
    );
    // Refresca el historial por si el ride cambió de estado
    ref.read(ridesHistoryProvider.notifier).refresh();
  }
}

// ─── Métrica pequeña ─────────────────────────────────────────────────────────

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

// ─── Diálogo publicar ride como ruta ─────────────────────────────────────────

/// Formulario para dar nombre y descripción a la ruta antes de publicarla.
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
      title: const Text('Publicar como ruta'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.ride.trackPoints.length} puntos GPS grabados',
              style: const TextStyle(color: Colors.grey),
            ),
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
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _publishing ? null : _publish,
          child: _publishing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Publicar'),
        ),
      ],
    );
  }
}
