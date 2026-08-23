import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Mis Rutas": listado de las rutas publicadas por el propio usuario.
/// Placeholder de la Fase 1 — se completa en la Fase 4 reutilizando las
/// tarjetas de routes_screen.dart contra GET /routes/user/{id}.
class MyRoutesScreen extends ConsumerWidget {
  const MyRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aquí verás las rutas que has publicado'),
          ],
        ),
      ),
    );
  }
}
