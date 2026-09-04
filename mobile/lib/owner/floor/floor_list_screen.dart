import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../pg/pg_models.dart';
import 'floor_models.dart';
import 'floor_repository.dart';

class FloorListScreen extends StatefulWidget {
  final String pgId;
  final Pg? pg;

  const FloorListScreen({super.key, required this.pgId, this.pg});

  @override
  State<FloorListScreen> createState() => _FloorListScreenState();
}

class _FloorListScreenState extends State<FloorListScreen> {
  final _repository = FloorRepository();
  late Future<List<Floor>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listForPg(widget.pgId);
  }

  void _reload() => setState(() => _future = _repository.listForPg(widget.pgId));

  Future<void> _openCreateDialog() async {
    final nameController = TextEditingController();
    final numberController = TextEditingController(text: '${0}');
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add a floor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Floor name (e.g. Ground Floor)')),
            const SizedBox(height: 12),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Floor number'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await _repository.create(
                  pgId: widget.pgId,
                  name: nameController.text.trim(),
                  floorNumber: int.tryParse(numberController.text.trim()) ?? 0,
                );
                if (context.mounted) Navigator.of(context).pop(true);
              } on ApiException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pg?.name ?? 'Floors')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Floor'),
      ),
      body: FutureBuilder<List<Floor>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final floors = snapshot.data ?? [];
          if (floors.isEmpty) {
            return const Center(child: Text('No floors yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: floors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final floor = floors[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.layers_outlined),
                  title: Text(floor.name),
                  subtitle: Text('Floor #${floor.floorNumber}'),
                  onTap: () => context.push('/owner/floors/${floor.id}/rooms', extra: floor),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
