import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
// 'geolocator' y 'mapbox_maps_flutter' exportan cada uno su propio
// `Position`/`LocationSettings`; usamos prefijo en geolocator para evitar
// la colisión de nombres.
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../data/map_matching_service.dart';
import '../../../shared/models/route_model.dart';

/// Pantalla de "seguir ruta": muestra la polyline EXACTA grabada por el autor
/// (no una ruta recalculada por un motor de direcciones) y añade guía de voz
/// por encima, usando la Mapbox Map Matching API para obtener instrucciones
/// de giro ancladas a tu propio trazado — no al camino "óptimo" que buscaría
/// Directions API (el mismo problema que ya tenías con Google Maps).
class RouteFollowScreen extends StatefulWidget {
  const RouteFollowScreen({super.key, required this.route});
  final RouteModel route;

  @override
  State<RouteFollowScreen> createState() => _RouteFollowScreenState();
}

class _RouteFollowScreenState extends State<RouteFollowScreen> {
  static const _offRouteThresholdMeters = 40.0;
  static const _distance = Distance();
  static const _announceThresholds = [300.0, 150.0, 50.0];

  final _matchingService = MapMatchingService();
  final _tts = FlutterTts();

  MapboxMap? _mapboxMap;
  StreamSubscription<geo.Position>? _positionSub;

  int? _lastNearestIndex;
  double? _distanceToRouteMeters;
  double? _remainingDistanceMeters;
  bool _following = false;
  bool _matching = false;
  DateTime? _lastCameraUpdate;

  MatchedRoute? _matchedRoute;
  int _currentStepIndex = 0;
  double? _minDistanceToManeuver;
  final Set<double> _announcedThresholds = {};

  List<LatLng> get _path => widget.route.path;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('es-ES');
    _tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // Activar el puck y dibujar/encuadrar la ruta no dependen entre sí:
    // antes iban en cadena secuencial (varias idas y vueltas al canal de
    // plataforma una detrás de otra), por eso la línea tardaba en aparecer.
    await Future.wait([
      map.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          puckBearingEnabled: true,
          puckBearing: PuckBearing.HEADING,
          pulsingEnabled: true,
        ),
      ),
      if (_path.length >= 2) _drawRouteAndFitCamera(map),
    ]);
  }

  Future<void> _drawRouteAndFitCamera(MapboxMap map) async {
    final manager = await map.annotations.createPolylineAnnotationManager();
    final coordinates = _path.map((p) => Position(p.longitude, p.latitude)).toList();
    final points = coordinates.map((p) => Point(coordinates: p)).toList();

    await Future.wait([
      manager.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coordinates),
          lineColor: Colors.deepOrange.toARGB32(),
          lineWidth: 5,
        ),
      ),
      map
          .cameraForCoordinatesPadding(
            points,
            CameraOptions(),
            MbxEdgeInsets(top: 80, left: 40, bottom: 80, right: 40),
            null,
            null,
          )
          .then(map.setCamera),
    ]);
  }

  Future<void> _toggleFollow() async {
    if (_following) {
      await _positionSub?.cancel();
      _positionSub = null;
      await _tts.stop();
      setState(() => _following = false);
      return;
    }

    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) return;
    }
    if (permission == geo.LocationPermission.deniedForever) return;

    setState(() => _matching = true);

    // Une el track grabado a carreteras reales y saca los giros paso a
    // paso. Si falla (sin red, tramo no encajable...) seguimos igualmente
    // con la polyline exacta, solo sin voz.
    final matched = await _matchingService.match(_path);

    if (!mounted) return;
    setState(() {
      _matchedRoute = matched;
      _currentStepIndex = 0;
      _minDistanceToManeuver = null;
      _announcedThresholds.clear();
      _matching = false;
      _following = true;
    });

    if (matched == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guía por voz no disponible ahora mismo; sigue el trazado en el mapa.'),
        ),
      );
    } else {
      await _tts.speak('Empezando a seguir la ruta');
    }

    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen((geo.Position pos) async {
      if (!mounted) return;
      final newLatLng = LatLng(pos.latitude, pos.longitude);

      final (nearestIndex, distToRoute) = _nearestPointOnPath(newLatLng);
      final remaining = _remainingDistance(nearestIndex);
      _lastNearestIndex = nearestIndex;

      setState(() {
        _distanceToRouteMeters = distToRoute;
        _remainingDistanceMeters = remaining;
      });

      _processStepProgress(newLatLng);

      // Cámara deliberadamente simple: solo centra, sin rotación ni
      // inclinación 3D. El emulador entrega posiciones en ráfagas
      // irregulares (Android las retiene con "location delivery blocked -
      // too fast" y las suelta de golpe); cualquier animación de giro se
      // pisaba con la siguiente y se veía a saltos. Además no relanzamos la
      // animación si la anterior aún no ha tenido tiempo de completarse.
      final now = DateTime.now();
      if (_lastCameraUpdate != null &&
          now.difference(_lastCameraUpdate!) < const Duration(milliseconds: 300)) {
        return;
      }
      _lastCameraUpdate = now;

      await _mapboxMap?.easeTo(
        CameraOptions(
          center: Point(coordinates: Position(newLatLng.longitude, newLatLng.latitude)),
          zoom: 16,
        ),
        MapAnimationOptions(duration: 300),
      );
    });
  }

  /// Avisa por voz según te acercas al próximo giro, y avanza al siguiente
  /// paso cuando lo hemos pasado.
  void _processStepProgress(LatLng position) {
    final route = _matchedRoute;
    if (route == null || _currentStepIndex >= route.steps.length) return;

    final step = route.steps[_currentStepIndex];
    final d = _distance.distance(position, step.maneuverLocation);

    _minDistanceToManeuver =
        _minDistanceToManeuver == null ? d : (d < _minDistanceToManeuver! ? d : _minDistanceToManeuver);

    for (final threshold in _announceThresholds) {
      if (d <= threshold && !_announcedThresholds.contains(threshold)) {
        _announcedThresholds.add(threshold);
        final phrase =
            threshold >= 100 ? 'En ${threshold.round()} metros, ${step.instruction}' : step.instruction;
        _tts.speak(phrase);
        break;
      }
    }

    // "Hemos pasado el giro": hubo un punto claramente cercano y ahora nos
    // alejamos, o hemos llegado prácticamente encima.
    final min = _minDistanceToManeuver!;
    final passedManeuver = min < 40 && d > min + 15;
    final arrivedClose = d < 15;
    if (passedManeuver || arrivedClose) {
      setState(() => _currentStepIndex++);
      _minDistanceToManeuver = null;
      _announcedThresholds.clear();
      if (_currentStepIndex >= route.steps.length) {
        _tts.speak('Has llegado al final de la ruta');
      }
    }
  }

  /// Punto del track grabado más cercano a [from]. Busca primero en una
  /// ventana alrededor del último índice conocido (mucho más barato y
  /// estable: evita que un tramo de la ruta que pasa cerca en otro punto
  /// "robe" el resultado) y solo recorre la ruta entera si no hay un
  /// resultado previo o si nos hemos alejado demasiado (p. ej. al empezar).
  (int, double) _nearestPointOnPath(LatLng from) {
    final last = _lastNearestIndex;
    if (last != null) {
      const window = 40;
      final start = (last - window).clamp(0, _path.length - 1);
      final end = (last + window).clamp(0, _path.length - 1);
      final (windowIndex, windowDist) = _searchNearest(from, start, end);
      if (windowDist < 100) return (windowIndex, windowDist);
    }
    return _searchNearest(from, 0, _path.length - 1);
  }

  (int, double) _searchNearest(LatLng from, int start, int end) {
    var bestIndex = start;
    var bestDist = double.infinity;
    for (var i = start; i <= end; i++) {
      final d = _distance.distance(from, _path[i]);
      if (d < bestDist) {
        bestDist = d;
        bestIndex = i;
      }
    }
    return (bestIndex, bestDist);
  }

  double _remainingDistance(int fromIndex) {
    var total = 0.0;
    for (var i = fromIndex; i < _path.length - 1; i++) {
      total += _distance.distance(_path[i], _path[i + 1]);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final offRoute = (_distanceToRouteMeters ?? 0) > _offRouteThresholdMeters;
    final route = _matchedRoute;
    final nextStep =
        (route != null && _currentStepIndex < route.steps.length) ? route.steps[_currentStepIndex] : null;

    return Scaffold(
      appBar: AppBar(title: Text('Siguiendo: ${widget.route.name}')),
      body: Stack(
        children: [
          MapWidget(
            styleUri: MapboxStyles.OUTDOORS,
            onMapCreated: _onMapCreated,
          ),

          if (_following)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  if (nextStep != null) ...[
                    _NextStepBanner(step: nextStep, distanceToStep: _minDistanceToManeuver),
                    const SizedBox(height: 8),
                  ],
                  _FollowHud(
                    offRoute: offRoute,
                    distanceToRoute: _distanceToRouteMeters,
                    remainingKm: _remainingDistanceMeters == null ? null : _remainingDistanceMeters! / 1000,
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _matching ? null : _toggleFollow,
        backgroundColor: _following
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        icon: _matching
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Icon(_following ? Icons.stop : Icons.navigation),
        label: Text(
          _matching ? 'Calculando guía…' : (_following ? 'Detener' : 'Empezar a seguir'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _NextStepBanner extends StatelessWidget {
  const _NextStepBanner({required this.step, required this.distanceToStep});

  final MatchedStep step;
  final double? distanceToStep;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primary,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.turn_right, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    distanceToStep == null ? '' : '${distanceToStep!.round()} m',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    step.instruction,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowHud extends StatelessWidget {
  const _FollowHud({
    required this.offRoute,
    required this.distanceToRoute,
    required this.remainingKm,
  });

  final bool offRoute;
  final double? distanceToRoute;
  final double? remainingKm;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: offRoute ? Colors.orange.shade100 : null,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  offRoute ? Icons.warning_amber : Icons.check_circle,
                  color: offRoute ? Colors.deepOrange : Colors.green,
                ),
                const SizedBox(height: 4),
                Text(
                  distanceToRoute == null
                      ? '—'
                      : '${distanceToRoute!.round()} m',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Text('De la ruta', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flag),
                const SizedBox(height: 4),
                Text(
                  remainingKm == null ? '—' : '${remainingKm!.toStringAsFixed(1)} km',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Text('Restante', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
