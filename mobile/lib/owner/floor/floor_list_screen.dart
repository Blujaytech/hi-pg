import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
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

  void _reload() =>
      setState(() => _future = _repository.listForPg(widget.pgId));

  Future<void> _refresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {
      // The FutureBuilder renders the error state.
    }
  }

  Future<void> _openCreateSheet(int suggestedNumber) async {
    final created = await showFormSheet<bool>(
      context,
      (_) => _FloorFormSheet(
        repository: _repository,
        pgId: widget.pgId,
        suggestedNumber: suggestedNumber,
      ),
    );
    if (created == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Floor>>(
      future: _future,
      builder: (context, snapshot) {
        final floors = snapshot.data ?? const <Floor>[];
        final ready = snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        final nextNumber = floors.isEmpty
            ? 0
            : floors.map((f) => f.floorNumber).reduce((a, b) => a > b ? a : b) +
                1;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Floors & rooms'),
                if (widget.pg != null)
                  Text(widget.pg!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          floatingActionButton: ready && floors.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () => _openCreateSheet(nextNumber),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add floor'),
                )
              : null,
          body: _buildBody(snapshot, floors, nextNumber),
        );
      },
    );
  }

  Widget _buildBody(
      AsyncSnapshot<List<Floor>> snapshot, List<Floor> floors, int nextNumber) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const AppLoadingView(label: 'Loading floors...');
    }
    if (snapshot.hasError) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : 'Floors could not be loaded.';
      return AppErrorView(message: message, onRetry: _reload);
    }
    if (floors.isEmpty) {
      return AppEmptyView(
        icon: Icons.layers_outlined,
        title: 'No floors yet',
        message: 'Add the first floor, then create its rooms and beds.',
        actionLabel: 'Add floor',
        actionIcon: Icons.add_rounded,
        onAction: () => _openCreateSheet(nextNumber),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
        itemCount: floors.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) return _PropertyHeader(pg: widget.pg, pgId: widget.pgId, floorCount: floors.length);
          final floor = floors[index - 1];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  context.push('/owner/floors/${floor.id}/rooms', extra: floor),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.fill,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '${floor.floorNumber}',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(floor.name,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text('Rooms and bed layout',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.subtle),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PropertyHeader extends StatelessWidget {
  final Pg? pg;
  final String pgId;
  final int floorCount;

  const _PropertyHeader({
    required this.pg,
    required this.pgId,
    required this.floorCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Icons.apartment_rounded,
                size: 46,
                color: AppColors.ink,
                background: Colors.white,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pg?.name ?? 'Property layout',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$floorCount floor${floorCount == 1 ? '' : 's'} configured',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .62),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeaderButton(
                icon: Icons.group_outlined,
                label: 'Customers',
                onTap: () =>
                    context.push('/owner/pgs/$pgId/students', extra: pg),
              ),
              const SizedBox(width: 10),
              _HeaderButton(
                icon: Icons.receipt_long_outlined,
                label: 'Expenses',
                onTap: () =>
                    context.push('/owner/pgs/$pgId/expenses', extra: pg),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 17),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloorFormSheet extends StatefulWidget {
  final FloorRepository repository;
  final String pgId;
  final int suggestedNumber;

  const _FloorFormSheet({
    required this.repository,
    required this.pgId,
    required this.suggestedNumber,
  });

  @override
  State<_FloorFormSheet> createState() => _FloorFormSheetState();
}

class _FloorFormSheetState extends State<_FloorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final TextEditingController _number =
      TextEditingController(text: '${widget.suggestedNumber}');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.create(
        pgId: widget.pgId,
        name: _name.text.trim(),
        floorNumber: int.parse(_number.text.trim()),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: FormSheet(
        icon: Icons.layers_rounded,
        title: 'Add a floor',
        subtitle: 'Rooms and beds are added inside it',
        children: [
          if (_error != null) ...[
            AppMessageBanner(
              icon: Icons.error_outline_rounded,
              message: _error!,
              color: AppColors.danger,
              background: AppColors.dangerSoft,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _name,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Floor name',
              hintText: 'e.g. Ground Floor',
              prefixIcon: Icon(Icons.layers_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Give the floor a name' : null,
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _number,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              labelText: 'Floor number',
              helperText: '0 for ground floor',
              prefixIcon: Icon(Icons.numbers_rounded),
            ),
            validator: (v) =>
                int.tryParse(v?.trim() ?? '') == null ? 'Enter a number' : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Add floor'),
          ),
        ],
      ),
    );
  }
}
