/// Configuración de Mapbox compartida por toda la app.
///
/// El token público (prefijo `pk.`) es seguro de embeber en el binario de la
/// app: solo permite renderizar mapas y no da acceso a operaciones de
/// facturación/descarga. El token SECRETO (`sk.`, usado para descargar el SDK
/// nativo durante el build) nunca debe estar aquí: vive en
/// `~/.gradle/gradle.properties` (Android) y en `~/.netrc` (iOS).
class MapboxConfig {
  MapboxConfig._();

  static const String accessToken =
      '***REMOVED-MAPBOX-TOKEN***';
}
