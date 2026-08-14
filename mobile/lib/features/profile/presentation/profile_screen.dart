import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../core/widgets/network_avatar.dart';

/// Perfil social del rider: se abre pulsando el avatar de la top bar.
/// Versión mínima por ahora (avatar + nombre); en la fase de Riders se
/// amplía con "Moto actual" y el feed de últimas rutas — ver
/// features/riders/presentation/rider_profile_screen.dart, que comparte
/// layout con esta pantalla para el caso "es mi propio perfil".
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: NetworkAvatar(
              imageUrl: user.avatarUrl,
              fallbackName: user.username,
              radius: 48,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user.username,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              user.email,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
