import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/mapbox_config.dart';

/// Un giro/instrucción de la ruta "enganchada" a carretera real.
class MatchedStep {
  const MatchedStep({
    required this.instruction,
    required this.distanceMeters,
    required this.maneuverLocation,
    this.roadName,
  });

  /// Texto de la instrucción (en español, si Mapbox tiene traducción para
  /// ese tipo de maniobra; si no, cae en inglés).
  final String instruction;

  /// Longitud de ESTE tramo (desde el giro anterior hasta este).
  final double distanceMeters;

  /// Punto exacto donde ocurre la maniobra.
  final LatLng maneuverLocation;

  final String? roadName;
}

class MatchedRoute {
  const MatchedRoute({required this.geometry, required this.steps});

  /// Geometría de la ruta ya "enganchada" a las carreteras reales (muy
  /// próxima a tu track grabado, pero corregida para seguir la calzada).
  final List<LatLng> geometry;

  final List<MatchedStep> steps;
}

/// Envuelve la Mapbox Map Matching API: convierte un track GPS grabado en
/// una ruta con instrucciones de giro paso a paso, ancladas a carreteras
/// reales — a diferencia de Directions API, respeta el trazado que grabó el
/// motero en vez de buscar el camino "óptimo" entre origen y destino.
///
/// https://docs.mapbox.com/api/navigation/map-matching/
class MapMatchingService {
  MapMatchingService() : _dio = Dio();

  // Dio "limpio", sin el baseUrl/interceptor JWT del backend propio: esta
  // llamada va directa a la API pública de Mapbox.
  final Dio _dio;

  static const _maxCoordinates = 100;

  /// Devuelve `null` si Mapbox no consigue encajar el track en carreteras
  /// (tramos muy cortos, zonas sin datos de calles, error de red…). El
  /// llamador debe tratarlo como "sin guía de voz disponible", no como un
  /// error fatal: seguir la polyline grabada sigue funcionando igual.
  Future<MatchedRoute?> match(List<LatLng> path) async {
    if (path.length < 2) return null;

    final sampled = _downsample(path, _maxCoordinates);
    final coordinates = sampled.map((p) => '${p.longitude},${p.latitude}').join(';');

    try {
      final response = await _dio.get(
        'https://api.mapbox.com/matching/v5/mapbox/driving/$coordinates',
        queryParameters: {
          'geometries': 'geojson',
          'steps': 'true',
          'overview': 'full',
          'language': 'es',
          'access_token': MapboxConfig.accessToken,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;

      final matchings = data['matchings'] as List<dynamic>?;
      if (matchings == null || matchings.isEmpty) return null;

      final match = matchings.first as Map<String, dynamic>;
      final geometry = _parseGeometry(match['geometry'] as Map<String, dynamic>);
      final steps = _parseSteps(match['legs'] as List<dynamic>? ?? const []);

      if (geometry.isEmpty) return null;
      return MatchedRoute(geometry: geometry, steps: steps);
    } catch (_) {
      // Sin conexión, timeout, respuesta inesperada... degradamos a "sin
      // guía de voz" en vez de romper la pantalla de seguimiento.
      return null;
    }
  }

  List<LatLng> _parseGeometry(Map<String, dynamic> geoJson) {
    final coords = geoJson['coordinates'] as List<dynamic>?;
    if (coords == null) return const [];
    return coords.map((c) {
      final pair = c as List<dynamic>;
      return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList();
  }

  List<MatchedStep> _parseSteps(List<dynamic> legs) {
    final steps = <MatchedStep>[];
    for (final legRaw in legs) {
      final leg = legRaw as Map<String, dynamic>;
      final legSteps = leg['steps'] as List<dynamic>? ?? const [];
      for (final stepRaw in legSteps) {
        final step = stepRaw as Map<String, dynamic>;
        final maneuver = step['maneuver'] as Map<String, dynamic>?;
        if (maneuver == null) continue;

        final instruction = maneuver['instruction'] as String? ?? '';
        // El primer paso ("depart") y el último ("arrive") no siempre traen
        // texto útil de giro; los saltamos como puntos de aviso de voz.
        if (instruction.isEmpty) continue;

        final location = maneuver['location'] as List<dynamic>?;
        if (location == null || location.length < 2) continue;

        steps.add(MatchedStep(
          instruction: instruction,
          distanceMeters: ((step['distance'] as num?) ?? 0).toDouble(),
          maneuverLocation:
              LatLng((location[1] as num).toDouble(), (location[0] as num).toDouble()),
          roadName: step['name'] as String?,
        ));
      }
    }
    return steps;
  }

  /// La API solo acepta hasta 100 puntos por petición; un track grabado cada
  /// pocos metros puede tener miles. Reducimos por muestreo uniforme,
  /// conservando siempre el primer y el último punto.
  List<LatLng> _downsample(List<LatLng> path, int maxPoints) {
    if (path.length <= maxPoints) return path;

    final step = (path.length - 1) / (maxPoints - 1);
    return List.generate(maxPoints, (i) => path[(i * step).round()]);
  }
}
