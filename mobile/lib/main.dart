import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
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
