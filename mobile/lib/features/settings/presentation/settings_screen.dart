import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../core/api/uploads_repository.dart';
import '../../../core/widgets/network_avatar.dart';
import '../../../shared/models/user_model.dart';

/// Ajustes: datos de cuenta, privacidad, acceso al historial de rides y
/// cerrar sesión. Abierta desde el engranaje de la top bar. Distinta del
/// perfil social (que se abre pulsando el avatar) — aquí vive la gestión
/// de la cuenta, allí el escaparate público del rider.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _uploadingAvatar = false;

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final url = await ref
          .read(uploadsRepositoryProvider)
          .uploadImage(File(picked.path));
      await ref.read(authProvider.notifier).updateProfile(avatarUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir la foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _renameUser(UserModel user) async {
    final controller = TextEditingController(text: user.username);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar nombre'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != user.username) {
      await ref.read(authProvider.notifier).updateProfile(username: newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                NetworkAvatar(
                  imageUrl: user.avatarUrl,
                  fallbackName: user.username,
                  radius: 40,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: _uploadingAvatar
                          ? const SizedBox(
                              height: 12, width: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _renameUser(user),
              child: Text(
                user.username,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
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
          const SizedBox(height: 24),
          const Divider(),

          // ── Privacidad: cuenta privada requiere aceptar cada Rider ────────
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Cuenta privada'),
            subtitle: const Text(
              'Quien quiera seguirte necesitará que aceptes su solicitud',
            ),
            value: user.isPrivate,
            onChanged: (value) =>
                ref.read(authProvider.notifier).updateProfile(isPrivate: value),
          ),

          const Divider(),

          // ── Acceso al historial de rides ─────────────────────────────────
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Mis rides'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/rides'),
          ),

          const Divider(),

          // ── Cerrar sesión ────────────────────────────────────────────────
          ListTile(
            leading: Icon(Icons.logout,
                color: Theme.of(context).colorScheme.error),
            title: Text(
              'Cerrar sesión',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo de confirmación antes de cerrar sesión.
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cerrar sesión',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}
