import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_state.dart';
import '../../shared/live_events/live_events_listener.dart';
import '../../core/api_exception.dart';
import 'pg_models.dart';
import 'pg_repository.dart';

class PgListScreen extends StatefulWidget {
  const PgListScreen({super.key});

  @override
  State<PgListScreen> createState() => _PgListScreenState();
}

class _PgListScreenState extends State<PgListScreen> {
  final _repository = PgRepository();
  late Future<List<Pg>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.list();
  }

  void _reload() => setState(() => _future = _repository.list());

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _PgFormDialog(),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return LiveEventsListener(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('My PGs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Dashboard',
            onPressed: () => context.push('/owner/dashboard'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Reports',
            onPressed: () => context.push('/owner/reports'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => context.read<AuthState>().logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add PG'),
      ),
      body: FutureBuilder<List<Pg>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Failed to load PGs';
            return Center(child: Text(message));
          }
          final pgs = snapshot.data ?? [];
          if (pgs.isEmpty) {
            return const Center(child: Text('No PGs yet. Tap "Add PG" to create your first property.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pgs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final pg = pgs[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.apartment),
                    title: Text(pg.name),
                    subtitle: Text('${pg.address}, ${pg.city}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(label: Text(pg.status == PgStatus.active ? 'Active' : 'Inactive')),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'floors') context.push('/owner/pgs/${pg.id}/floors', extra: pg);
                            if (value == 'students') context.push('/owner/pgs/${pg.id}/students', extra: pg);
                            if (value == 'expenses') context.push('/owner/pgs/${pg.id}/expenses', extra: pg);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'floors', child: Text('Floors & Rooms')),
                            PopupMenuItem(value: 'students', child: Text('Students')),
                            PopupMenuItem(value: 'expenses', child: Text('Expenses')),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => context.push('/owner/pgs/${pg.id}/floors', extra: pg),
                  ),
                );
              },
            ),
          );
        },
      ),
      ),
    );
  }
}

class _PgFormDialog extends StatefulWidget {
  const _PgFormDialog();

  @override
  State<_PgFormDialog> createState() => _PgFormDialogState();
}

class _PgFormDialogState extends State<_PgFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  GenderPreference _gender = GenderPreference.coEd;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PgRepository().create(
        name: _name.text.trim(),
        address: _address.text.trim(),
        city: _city.text.trim(),
        genderPreference: _gender,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a PG'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'PG name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Address'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GenderPreference>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender preference'),
                items: GenderPreference.values
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.label)))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}
