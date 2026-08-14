import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/config/mapbox_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  // MapboxOptions.setAccessToken registra un canal de plataforma y necesita
  // el binding de Flutter ya inicializado; si se llama antes, lanza
  // "Binding has not yet been initialized" y la app se queda colgada en el
  // splash nativo sin pintar nada (justo lo que pasaba).
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(MapboxConfig.accessToken);
  runApp(
    // ProviderScope es el "contenedor" de Riverpod.
    // Debe envolver TODA la app para que cualquier widget pueda leer providers.
    const ProviderScope(
      child: RydrApp(),
    ),
  );
}

// ConsumerWidget = Widget normal + acceso a `ref` para leer providers
class RydrApp extends ConsumerWidget {
  const RydrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch → suscribe al provider y reconstruye si cambia
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Rydr',
      theme: AppTheme.theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
