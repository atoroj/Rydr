import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'motorbikes_provider.dart';
import '../../../shared/models/motorbike_model.dart';

class MotorbikesScreen extends ConsumerWidget {
  const MotorbikesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motorbikesAsync = ref.watch(motorbikesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Motos')),
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
                separatorBuilder: (context, index) => const SizedBox(height: 8),
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

class _MotorbikeCard extends StatelessWidget {
  const _MotorbikeCard(this.motorbike);
  final MotorbikeModel motorbike;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.two_wheeler),
        title: Text(motorbike.displayName),
        subtitle: Text('${motorbike.type} · ${motorbike.cc} cc'),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.ref.read(motorbikesProvider.notifier).addMotorbike(
          type: _selectedType,
          brand: _brandCtrl.text.trim(),
          model: _modelCtrl.text.trim(),
          cc: int.parse(_ccCtrl.text.trim()),
          alias: _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
        );
    if (mounted) Navigator.pop(context);
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
            FilledButton(onPressed: _submit, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}
