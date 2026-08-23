import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- AÑADIDO PARA GOOGLE MAPS
import 'package:latlong2/latlong.dart'; // <-- AÑADIDO PARA MANEJAR LAS COORDENADAS
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'route_follow_screen.dart';
import 'routes_provider.dart';
import '../../../shared/models/route_model.dart';

class RoutesScreen extends ConsumerWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(routesProvider);

    // El AppBar propio desapareció: el título y las acciones globales
    // (avatar, ajustes) los pone la top bar del shell (_MainShell). El
    // refresco pasa a ser un gesto de pull-to-refresh, más cómodo con
    // guantes que acertarle a un icono pequeño.
    return Scaffold(
      body: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (routes) => RefreshIndicator(
          onRefresh: () => ref.read(routesProvider.notifier).refresh(),
          child: routes.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Todavía no hay rutas publicadas'),
                        ],
                      ),
                    ),
                  ],
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

  Future<void> _exportarAGpx(BuildContext context, RouteModel route) async {
    if (route.path.isEmpty) return;

    // 1. Crear la estructura XML del estándar GPX
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="rydr" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${route.name}</name>');
    buffer.writeln('    <trkseg>');

    for (final point in route.path) {
      buffer.writeln('      <trkpt lat="${point.latitude}" lon="${point.longitude}"></trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    try {
      // 2. Guardar el archivo temporalmente en el dispositivo
      final tempDir = await getTemporaryDirectory();
      final fileName = '${route.name.replaceAll(RegExp(r'[^\w\s]+'), '')}.gpx';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(buffer.toString());

      // 3. Abrir la hoja nativa de compartir (NUEVA SINTAXIS)
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Ruta para GPS: ${route.name}',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar GPX: $e')),
        );
      }
    }
  }

  // --- FUNCIÓN MÁGICA PARA ABRIR GOOGLE MAPS ---
  Future<void> _abrirEnGoogleMaps(List<LatLng> trackPoints) async {
    if (trackPoints.isEmpty) return;

    if (trackPoints.length == 1) {
      final dest = trackPoints.first;
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${dest.latitude},${dest.longitude}');
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }

    final origin = trackPoints.first;
    final destination = trackPoints.last;

    // Extraemos hasta 8 puntos intermedios
    final waypoints = <LatLng>[];
    if (trackPoints.length > 2) {
      int step = (trackPoints.length / 8).ceil();
      for (int i = step; i < trackPoints.length - 1; i += step) {
        waypoints.add(trackPoints[i]);
        if (waypoints.length >= 8) break;
      }
    }

    String urlStr = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&travelmode=driving';

    if (waypoints.isNotEmpty) {
      String waypointsStr = waypoints.map((wp) => '${wp.latitude},${wp.longitude}').join('|');
      urlStr += '&waypoints=$waypointsStr';
    }

    final url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('No se pudo abrir Google Maps');
    }
  }
  // ---------------------------------------------

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
                : _RouteMiniMap(path: path, color: Theme.of(context).colorScheme.primary),
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
                  onPressed: () => _exportarAGpx(context, route),
                  icon: const Icon(Icons.download),
                  label: const Text('Exportar archivo GPX'),
                ),
                // --- BOTÓN ACTUALIZADO ---
                FilledButton.icon(
                  onPressed: () async {
                    // 1. Abrimos Google Maps externamente
                    await _abrirEnGoogleMaps(path);

                    // 2. Sumamos 1 a las veces que se ha hecho la ruta en tu backend
                    await ref
                        .read(routesProvider.notifier)
                        .markAsRidden(route.id);

                    // 3. Cerramos la pantalla
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('¡Navegar en Google Maps!'),
                ),
                FilledButton.icon(
                  onPressed: path.length < 2
                      ? null
                      : () async {
                          // Abrimos el "seguir ruta" integrado en la app:
                          // sigue tu track EXACTO, sin recalcular como haría
                          // un motor de rutas.
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RouteFollowScreen(route: route),
                            ),
                          );

                          if (context.mounted) {
                            await ref
                                .read(routesProvider.notifier)
                                .markAsRidden(route.id);
                          }
                        },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Seguir ruta en la app'),
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

// ─── Mini-mapa Mapbox del recorrido (solo lectura, sin seguimiento) ──────────

class _RouteMiniMap extends StatelessWidget {
  const _RouteMiniMap({required this.path, required this.color});
  final List<LatLng> path;
  final Color color;

  Future<void> _onMapCreated(MapboxMap map) async {
    final manager = await map.annotations.createPolylineAnnotationManager();
    await manager.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: path.map((p) => Position(p.longitude, p.latitude)).toList(),
        ),
        lineColor: color.toARGB32(),
        lineWidth: 4,
      ),
    );

    final camera = await map.cameraForCoordinatesPadding(
      path.map((p) => Point(coordinates: Position(p.longitude, p.latitude))).toList(),
      CameraOptions(),
      MbxEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
      null,
      null,
    );
    await map.setCamera(camera);
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      styleUri: MapboxStyles.OUTDOORS,
      onMapCreated: _onMapCreated,
    );
  }
}