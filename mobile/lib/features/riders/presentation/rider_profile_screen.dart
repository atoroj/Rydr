import 'package:flutter/material.dart';

/// Perfil público de otro rider (`/riders/:id`). Placeholder de la Fase 1 —
/// se completa en la Fase 6 con "Moto actual" + feed de últimas rutas y las
/// reglas de visibilidad de cuenta privada.
class RiderProfileScreen extends StatelessWidget {
  const RiderProfileScreen({super.key, required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rider')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
