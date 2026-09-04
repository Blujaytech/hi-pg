import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import 'complaint_models.dart';
import 'complaint_repository.dart';

class ComplaintListScreen extends StatefulWidget {
  final String studentId;
  final String? studentName;

  const ComplaintListScreen({super.key, required this.studentId, this.studentName});

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

  void _reload() => setState(() => _future = _repository.listForStudent(widget.studentId));

  Future<void> _openCreateDialog() async {
    final descriptionController = TextEditingController();
    ComplaintCategory category = ComplaintCategory.maintenance;
    ComplaintPriority priority = ComplaintPriority.medium;
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Log a complaint'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
                DropdownButtonFormField<ComplaintCategory>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ComplaintCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                  onChanged: (v) => setDialogState(() => category = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ComplaintPriority>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: ComplaintPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                  onChanged: (v) => setDialogState(() => priority = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (descriptionController.text.trim().isEmpty) {
                  setDialogState(() => error = 'Description is required');
                  return;
                }
                try {
                  await _repository.create(
                    studentId: widget.studentId,
                    category: category,
                    priority: priority,
                    description: descriptionController.text.trim(),
                  );
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Log complaint'),
            ),
          ],
        ),
      ),
    );
    if (created == true) _reload();
  }

  Future<void> _openUpdateStatusDialog(Complaint complaint) async {
    ComplaintStatus status = complaint.status;
    final notesController = TextEditingController(text: complaint.resolutionNotes ?? '');
    String? error;

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Update status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
              DropdownButtonFormField<ComplaintStatus>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ComplaintStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                onChanged: (v) => setDialogState(() => status = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: status == ComplaintStatus.resolved ? 'Resolution notes (required)' : 'Resolution notes (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await _repository.updateStatus(complaint.id, status, resolutionNotes: notesController.text.trim());
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (updated == true) _reload();
  }

  Color _statusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.open:
        return Colors.red;
      case ComplaintStatus.inProgress:
        return Colors.orange;
      case ComplaintStatus.resolved:
        return Colors.green;
      case ComplaintStatus.closed:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Complaints${widget.studentName != null ? ' • ${widget.studentName}' : ''}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.report_problem_outlined),
        label: const Text('Log Complaint'),
      ),
      body: FutureBuilder<List<Complaint>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final complaints = snapshot.data ?? [];
          if (complaints.isEmpty) {
            return const Center(child: Text('No complaints logged.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: complaints.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final complaint = complaints[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(complaint.status).withOpacity(0.15),
                    child: Icon(Icons.report_outlined, color: _statusColor(complaint.status)),
                  ),
                  title: Text('${complaint.category.label} • ${complaint.priority.label}'),
                  subtitle: Text(complaint.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Chip(label: Text(complaint.status.label)),
                  onTap: () => _openUpdateStatusDialog(complaint),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
