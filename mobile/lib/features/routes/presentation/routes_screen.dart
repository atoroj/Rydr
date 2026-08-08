import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routes_provider.dart';
import '../../../shared/models/route_model.dart';

class RoutesScreen extends ConsumerWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(routesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(routesProvider.notifier).refresh(),
          ),
        ],
      ),
      body: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (routes) => routes.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Todavía no hay rutas publicadas'),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: routes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _RouteCard(
                  route: routes[i],
                  onTap: () => _showRouteDetail(context, ref, routes[i]),
                ),
              ),
      ),
    );
  }

  void _showRouteDetail(
      BuildContext context, WidgetRef ref, RouteModel route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteDetailScreen(route: route, ref: ref),
      ),
    );
  }
}

// ─── Tarjeta de ruta ─────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route, required this.onTap});
  final RouteModel route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(route.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              if (route.description != null) ...[
                const SizedBox(height: 4),
                Text(route.description!,
                    style: const TextStyle(color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatChip(
                    icon: Icons.straighten,
                    label: '${route.distanceKm} km',
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.timer_outlined,
                    label: '${route.durationMinutes} min',
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.people_outline,
                    label: '${route.timesRidden} veces',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Detalle de ruta ──────────────────────────────────────────────────────────

class RouteDetailScreen extends StatelessWidget {
  const RouteDetailScreen({super.key, required this.route, required this.ref});
  final RouteModel route;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final path = route.path;

    return Scaffold(
      appBar: AppBar(title: Text(route.name)),
      body: Column(
        children: [
          // Mini mapa con el recorrido
          SizedBox(
            height: 280,
            child: path.isEmpty
                ? const Center(child: Text('Sin datos de recorrido'))
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: path[path.length ~/ 2],
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.rydr.rydr',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: path,
                            strokeWidth: 4,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // Datos de la ruta
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (route.description != null)
                  Text(route.description!,
                      style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _DetailStat(
                        icon: Icons.straighten,
                        value: '${route.distanceKm} km',
                        label: 'Distancia'),
                    _DetailStat(
                        icon: Icons.timer,
                        value: '${route.durationMinutes} min',
                        label: 'Duración'),
                    _DetailStat(
                        icon: Icons.people,
                        value: '${route.timesRidden}',
                        label: 'La han hecho'),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(routesProvider.notifier)
                        .markAsRidden(route.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('¡Voy a hacer esta ruta!'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat(
      {required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
