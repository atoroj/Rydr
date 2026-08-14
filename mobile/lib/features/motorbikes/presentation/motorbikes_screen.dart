import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'motorbikes_provider.dart';
import '../../../core/api/uploads_repository.dart';
import '../../../core/widgets/cover_image.dart';
import '../../../shared/models/motorbike_model.dart';

class MotorbikesScreen extends ConsumerWidget {
  const MotorbikesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motorbikesAsync = ref.watch(motorbikesProvider);

    // El AppBar propio desapareció: el título lo pone la top bar del shell.
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMotorbikeSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: motorbikesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (motorbikes) => motorbikes.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.two_wheeler, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Aún no tienes motos registradas'),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: motorbikes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _MotorbikeCard(motorbikes[i]),
              ),
      ),
    );
  }

  void _showAddMotorbikeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddMotorbikeSheet(ref: ref),
    );
  }
}

/// Tarjeta del garaje: fotografía, marca+modelo, cc y, si es la moto con la
/// que se sale por defecto, una insignia "Actual" + acción para marcarla.
class _MotorbikeCard extends ConsumerWidget {
  const _MotorbikeCard(this.motorbike);
  final MotorbikeModel motorbike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              CoverImage(
                imageUrl: motorbike.photoUrl,
                fallbackIcon: Icons.two_wheeler,
                height: 140,
              ),
              if (motorbike.isCurrent)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Chip(
                    label: const Text('Actual'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          ListTile(
            title: Text(motorbike.displayName),
            subtitle: Text('${motorbike.type} · ${motorbike.cc} cc'),
            trailing: motorbike.isCurrent
                ? null
                : TextButton(
                    onPressed: () =>
                        ref.read(motorbikesProvider.notifier).setCurrent(motorbike.id),
                    child: const Text('Marcar como actual'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddMotorbikeSheet extends StatefulWidget {
  const _AddMotorbikeSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_AddMotorbikeSheet> createState() => _AddMotorbikeSheetState();
}

class _AddMotorbikeSheetState extends State<_AddMotorbikeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _ccCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  String _selectedType = 'Naked';
  File? _photo;
  bool _submitting = false;

  static const _types = [
    'Naked', 'Sport', 'Custom', 'ATV', 'Touring', 'Motocross', 'Scooter'
  ];

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _ccCtrl.dispose();
    _aliasCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      String? photoUrl;
      if (_photo != null) {
        photoUrl =
            await widget.ref.read(uploadsRepositoryProvider).uploadImage(_photo!);
      }
      await widget.ref.read(motorbikesProvider.notifier).addMotorbike(
            type: _selectedType,
            brand: _brandCtrl.text.trim(),
            model: _modelCtrl.text.trim(),
            cc: int.parse(_ccCtrl.text.trim()),
            alias: _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
            photoUrl: photoUrl,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la moto: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nueva moto', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickPhoto,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: _photo == null
                      ? Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 32),
                              SizedBox(height: 4),
                              Text('Añadir foto'),
                            ],
                          ),
                        )
                      : Image.file(_photo!, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandCtrl,
              decoration: const InputDecoration(labelText: 'Marca', border: OutlineInputBorder()),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modelCtrl,
              decoration: const InputDecoration(labelText: 'Modelo', border: OutlineInputBorder()),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ccCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cilindrada (cc)', border: OutlineInputBorder()),
              validator: (v) => v == null || int.tryParse(v) == null ? 'Número válido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aliasCtrl,
              decoration: const InputDecoration(
                labelText: 'Alias (opcional)',
                hintText: 'p.ej. La Negra',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
