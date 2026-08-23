import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sección social "Riders": buscador + siguiendo/seguidores/solicitudes.
/// Placeholder de la Fase 1 — se completa en la Fase 6 (módulo de follow).
class RidersScreen extends ConsumerWidget {
  const RidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aquí verás a otros riders'),
          ],
        ),
      ),
    );
  }
}
