import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../pg/pg_models.dart';
import 'student_models.dart';
import 'student_repository.dart';

class StudentListScreen extends StatefulWidget {
  final String pgId;
  final Pg? pg;

  const StudentListScreen({super.key, required this.pgId, this.pg});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final _repository = StudentRepository();
  late Future<List<Student>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listForPg(widget.pgId);
  }

  void _reload() => setState(() => _future = _repository.listForPg(widget.pgId));

  Future<void> _openCreateDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final guardianController = TextEditingController();
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add a student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextField(controller: guardianController, decoration: const InputDecoration(labelText: 'Guardian name (optional)')),
                const SizedBox(height: 4),
                const Text('A bed can be assigned afterwards from the student list.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                  setDialogState(() => error = 'Name and phone are required');
                  return;
                }
                try {
                  await _repository.create(
                    pgId: widget.pgId,
                    fullName: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    guardianName: guardianController.text.trim().isEmpty ? null : guardianController.text.trim(),
                    dateOfJoining: DateTime.now(),
                  );
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (created == true) _reload();
  }

  Future<void> _openAssignBedDialog(Student student) async {
    final beds = await _repository.listAvailableBeds(widget.pgId);
    if (!mounted) return;
    if (beds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No available beds in this PG right now.')));
      return;
    }

    final selected = await showDialog<AvailableBed>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('Assign a bed to ${student.fullName}'),
        children: beds
            .map((bed) => SimpleDialogOption(
                  onPressed: () => Navigator.of(dialogContext).pop(bed),
                  child: Text('${bed.floorName} • Room ${bed.roomNumber} • ${bed.label}'),
                ))
            .toList(),
      ),
    );

    if (selected != null) {
      try {
        await _repository.assignBed(student.id, selected.id);
        _reload();
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmMoveOut(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move out student?'),
        content: Text('${student.fullName} will be marked as moved out and their bed freed up.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Move out')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _repository.moveOut(student.id);
        _reload();
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Students${widget.pg != null ? ' • ${widget.pg!.name}' : ''}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Student'),
      ),
      body: FutureBuilder<List<Student>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final students = snapshot.data ?? [];
          if (students.isEmpty) {
            return const Center(child: Text('No students yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final student = students[index];
              final isActive = student.status == StudentStatus.active;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?')),
                  title: Text(student.fullName),
                  subtitle: Text([
                    student.phone,
                    if (student.bedLabel != null) 'Bed: ${student.bedLabel}' else 'No bed assigned',
                    if (!isActive) 'Moved out',
                  ].join(' • ')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'assign') _openAssignBedDialog(student);
                      if (value == 'move_out') _confirmMoveOut(student);
                      if (value == 'fees') context.push('/owner/students/${student.id}/fees', extra: student.fullName);
                      if (value == 'complaints') context.push('/owner/students/${student.id}/complaints', extra: student.fullName);
                      if (value == 'receipts') context.push('/owner/students/${student.id}/receipts', extra: student.fullName);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'fees', child: Text('Fees')),
                      const PopupMenuItem(value: 'complaints', child: Text('Complaints')),
                      const PopupMenuItem(value: 'receipts', child: Text('Receipts')),
                      if (isActive) PopupMenuItem(value: 'assign', child: Text(student.bedId == null ? 'Assign bed' : 'Change bed')),
                      if (isActive) const PopupMenuItem(value: 'move_out', child: Text('Move out')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
