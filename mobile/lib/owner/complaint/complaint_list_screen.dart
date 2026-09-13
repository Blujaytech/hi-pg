import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import 'complaint_models.dart';
import 'complaint_repository.dart';
import 'complaint_visuals.dart';

class ComplaintListScreen extends StatefulWidget {
  final String studentId;
  final String? studentName;

  const ComplaintListScreen(
      {super.key, required this.studentId, this.studentName});

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> {
  final _repository = ComplaintRepository();
  late Future<List<Complaint>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listForStudent(widget.studentId);
  }

  void _reload() =>
      setState(() => _future = _repository.listForStudent(widget.studentId));

  Future<void> _refresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {
      // The FutureBuilder renders the error state.
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showFormSheet<bool>(
      context,
      (_) => _ComplaintFormSheet(
          repository: _repository, studentId: widget.studentId),
    );
    if (created == true && mounted) _reload();
  }

  Future<void> _openUpdateSheet(Complaint complaint) async {
    final updated = await showFormSheet<bool>(
      context,
      (_) => _StatusFormSheet(repository: _repository, complaint: complaint),
    );
    if (updated == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Complaint>>(
      future: _future,
      builder: (context, snapshot) {
        final complaints = snapshot.data ?? const <Complaint>[];
        final ready = snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Complaints'),
                if (widget.studentName != null)
                  Text(widget.studentName!,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          floatingActionButton: ready && complaints.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _openCreateSheet,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Log complaint'),
                )
              : null,
          body: _buildBody(snapshot, complaints),
        );
      },
    );
  }

  Widget _buildBody(
      AsyncSnapshot<List<Complaint>> snapshot, List<Complaint> complaints) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const AppLoadingView(label: 'Loading complaints...');
    }
    if (snapshot.hasError) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : 'Complaints could not be loaded.';
      return AppErrorView(message: message, onRetry: _reload);
    }
    if (complaints.isEmpty) {
      return AppEmptyView(
        icon: Icons.task_alt_rounded,
        title: 'No complaints',
        message: 'Nothing has been reported for this customer.',
        actionLabel: 'Log complaint',
        actionIcon: Icons.add_rounded,
        onAction: _openCreateSheet,
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
        itemCount: complaints.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final complaint = complaints[index];
          return _ComplaintCard(
            complaint: complaint,
            onTap: () => _openUpdateSheet(complaint),
          );
        },
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final VoidCallback onTap;

  const _ComplaintCard({required this.complaint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(icon: complaint.category.icon, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(complaint.category.label,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('d MMM yyyy, h:mm a')
                              .format(complaint.createdAt.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                      label: complaint.status.label,
                      tone: complaint.status.tone),
                ],
              ),
              const SizedBox(height: 12),
              Text(complaint.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.flag_rounded,
                      size: 15, color: complaint.priority.color),
                  const SizedBox(width: 5),
                  Text('${complaint.priority.label} priority',
                      style: TextStyle(
                          color: complaint.priority.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const Text('Update',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
              if (complaint.resolutionNotes != null &&
                  complaint.resolutionNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(complaint.resolutionNotes!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.ink)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ComplaintFormSheet extends StatefulWidget {
  final ComplaintRepository repository;
  final String studentId;

  const _ComplaintFormSheet(
      {required this.repository, required this.studentId});

  @override
  State<_ComplaintFormSheet> createState() => _ComplaintFormSheetState();
}

class _ComplaintFormSheetState extends State<_ComplaintFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  ComplaintCategory _category = ComplaintCategory.maintenance;
  ComplaintPriority _priority = ComplaintPriority.medium;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
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
        studentId: widget.studentId,
        category: _category,
        priority: _priority,
        description: _description.text.trim(),
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
        icon: Icons.report_problem_rounded,
        title: 'Log a complaint',
        subtitle: 'Record an issue raised by this customer',
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
          DropdownButtonFormField<ComplaintCategory>(
            initialValue: _category,
            decoration: InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(_category.icon),
            ),
            items: ComplaintCategory.values
                .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 16),
          Text('Priority', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          SegmentedButton<ComplaintPriority>(
            segments: ComplaintPriority.values
                .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                .toList(),
            selected: {_priority},
            showSelectedIcon: false,
            onSelectionChanged: _saving
                ? null
                : (value) => setState(() => _priority = value.first),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            enabled: !_saving,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Description is required'
                : null,
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
                : const Text('Log complaint'),
          ),
        ],
      ),
    );
  }
}

class _StatusFormSheet extends StatefulWidget {
  final ComplaintRepository repository;
  final Complaint complaint;

  const _StatusFormSheet({required this.repository, required this.complaint});

  @override
  State<_StatusFormSheet> createState() => _StatusFormSheetState();
}

class _StatusFormSheetState extends State<_StatusFormSheet> {
  late ComplaintStatus _status = widget.complaint.status;
  late final TextEditingController _notes =
      TextEditingController(text: widget.complaint.resolutionNotes ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    // Mirrors the backend rule (ADR-0010) so the owner gets instant feedback.
    if (_status == ComplaintStatus.resolved && _notes.text.trim().isEmpty) {
      setState(() => _error = 'Add resolution notes to mark this resolved.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateStatus(widget.complaint.id, _status,
          resolutionNotes: _notes.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      icon: widget.complaint.category.icon,
      title: 'Update status',
      subtitle: widget.complaint.category.label,
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in ComplaintStatus.values)
              ChoiceChip(
                label: Text(status.label),
                selected: _status == status,
                showCheckmark: false,
                selectedColor: AppColors.ink,
                backgroundColor: AppColors.fill,
                labelStyle: TextStyle(
                  color: _status == status ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _status = status),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notes,
          enabled: !_saving,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: _status == ComplaintStatus.resolved
                ? 'Resolution notes (required)'
                : 'Resolution notes (optional)',
            alignLabelWithHint: true,
          ),
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
              : const Text('Save'),
        ),
      ],
    );
  }
}
