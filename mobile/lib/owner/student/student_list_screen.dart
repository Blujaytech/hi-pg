import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
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

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Kept temporarily for legacy locally-created records; no UI route exposes it.
  // ignore: unused_element
  Future<void> _openCreateSheet() async {
    final created = await showFormSheet<bool>(
      context,
      (_) => _StudentFormSheet(repository: _repository, pgId: widget.pgId),
    );
    if (created == true && mounted) {
      _reload();
      _toast('Customer added. Assign a bed whenever you are ready.');
    }
  }

  // ignore: unused_element
  Future<void> _openAssignBedSheet(Student student) async {
    final List<AvailableBed> beds;
    try {
      beds = await _repository.listAvailableBeds(widget.pgId);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
      return;
    }
    if (!mounted) return;
    if (beds.isEmpty) {
      _toast('No available beds in this PG right now.');
      return;
    }

    final selected = await showModalBottomSheet<AvailableBed>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose a bed',
                      style: Theme.of(sheetContext).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text('For ${student.fullName}',
                      style: Theme.of(sheetContext).textTheme.bodySmall),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: beds.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, index) {
                  final bed = beds[index];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    leading: const IconTile(icon: Icons.bed_outlined, size: 40),
                    title: Text(bed.label,
                        style: Theme.of(sheetContext).textTheme.titleSmall),
                    subtitle: Text('${bed.floorName} · Room ${bed.roomNumber}'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.subtle),
                    onTap: () => Navigator.of(sheetContext).pop(bed),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    try {
      await _repository.assignBed(student.id, selected.id);
      if (!mounted) return;
      _reload();
      _toast('${student.fullName} is now in ${selected.label}.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _confirmMoveOut(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move out customer?'),
        content: Text(
            '${student.fullName} will be marked as moved out and their bed freed up.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Move out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.moveOut(student.id);
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _openActions(Student student) async {
    final isActive = student.status == StudentStatus.active;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: _Avatar(name: student.fullName, active: isActive),
                title: Text(student.fullName,
                    style: Theme.of(sheetContext).textTheme.titleMedium),
                subtitle: Text(student.phone),
              ),
              const Divider(height: 20),
              const _ActionTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Fees',
                  value: 'fees'),
              const _ActionTile(
                  icon: Icons.report_problem_outlined,
                  label: 'Complaints',
                  value: 'complaints'),
              const _ActionTile(
                  icon: Icons.description_outlined,
                  label: 'Receipts',
                  value: 'receipts'),
              if (isActive)
                const _ActionTile(
                  icon: Icons.logout_rounded,
                  label: 'Move out',
                  value: 'move_out',
                  destructive: true,
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'fees':
        context.push('/owner/students/${student.id}/fees',
            extra: student.fullName);
      case 'complaints':
        context.push('/owner/students/${student.id}/complaints',
            extra: student.fullName);
      case 'receipts':
        context.push('/owner/students/${student.id}/receipts',
            extra: student.fullName);
      case 'move_out':
        _confirmMoveOut(student);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Student>>(
      future: _future,
      builder: (context, snapshot) {
        final students = snapshot.data ?? const <Student>[];
        return Scaffold(
          appBar: AppBar(
            title: _TitleWithSubtitle(
                title: 'Customers', subtitle: widget.pg?.name),
          ),
          body: _buildBody(snapshot, students),
        );
      },
    );
  }

  Widget _buildBody(
      AsyncSnapshot<List<Student>> snapshot, List<Student> students) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const AppLoadingView(label: 'Loading customers...');
    }
    if (snapshot.hasError) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : 'Customers could not be loaded.';
      return AppErrorView(message: message, onRetry: _reload);
    }
    if (students.isEmpty) {
      return const AppEmptyView(
        icon: Icons.people_outline_rounded,
        title: 'No customers yet',
        message:
            'Customers appear here automatically after they choose a bed and begin booking.',
      );
    }
    final active =
        students.where((s) => s.status == StudentStatus.active).length;
    final withoutBed = students
        .where((s) => s.status == StudentStatus.active && s.bedLabel == null)
        .length;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
        itemCount: students.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(label: '$active active', tone: StatusTone.dark),
                  if (students.length > active)
                    StatusPill(label: '${students.length - active} moved out'),
                  if (withoutBed > 0)
                    StatusPill(
                      label: '$withoutBed without a bed',
                      tone: StatusTone.warning,
                    ),
                ],
              ),
            );
          }
          final student = students[index - 1];
          return _StudentCard(
            student: student,
            onTap: () => _openActions(student),
          );
        },
      ),
    );
  }
}

class _TitleWithSubtitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _TitleWithSubtitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        if (subtitle != null)
          Text(subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;

  const _StudentCard({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = student.status != StudentStatus.movedOut;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Avatar(name: student.fullName, active: isActive),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(student.phone,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (!isActive)
                          const StatusPill(label: 'Moved out')
                        else if (student.bedLabel != null)
                          StatusPill(
                            label:
                                'Room ${student.roomNumber ?? '—'} · ${student.bedLabel}',
                            icon: Icons.bed_outlined,
                          )
                        else
                          const StatusPill(
                            label: 'No bed yet',
                            tone: StatusTone.warning,
                            icon: Icons.bed_outlined,
                          ),
                        if (student.bookingStatus == 'DIRECT_PAYMENT_REVIEW')
                          const StatusPill(
                            label: 'Payment verification pending',
                            tone: StatusTone.warning,
                          )
                        else if (student.bookingStatus == 'PAYMENT_PENDING')
                          const StatusPill(
                            label: 'Payment pending',
                            tone: StatusTone.warning,
                          ),
                      ],
                    ),
                    if (student.plannedMoveOutDate != null ||
                        (student.bookingType == 'DAY_WISE' &&
                            student.checkOutDate != null)) ...[
                      const SizedBox(height: 8),
                      Text(
                        student.plannedMoveOutDate != null
                            ? 'Move-out notice: ${DateFormat('d MMM yyyy').format(student.plannedMoveOutDate!)}${student.noticeShortfallDays > 0 ? ' · ${student.noticeShortfallDays} day shortfall' : ''}'
                            : 'Day-wise checkout: ${DateFormat('d MMM yyyy').format(student.checkOutDate!)} at ${_formatTime(student.checkOutTime)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: student.noticeShortfallDays > 0
                                  ? AppColors.warning
                                  : AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String? value) {
    if (value == null || value.length < 5) return '11:00 AM';
    final parts = value.substring(0, 5).split(':');
    final date = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('h:mm a').format(date);
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final bool active;

  const _Avatar({required this.name, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.ink : AppColors.fill,
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
        style: TextStyle(
          color: active ? Colors.white : AppColors.muted,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool destructive;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.value,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.ink;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(icon, color: color),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: () => Navigator.of(context).pop(value),
    );
  }
}

class _StudentFormSheet extends StatefulWidget {
  final StudentRepository repository;
  final String pgId;

  const _StudentFormSheet({required this.repository, required this.pgId});

  @override
  State<_StudentFormSheet> createState() => _StudentFormSheetState();
}

class _StudentFormSheetState extends State<_StudentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _guardian = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _guardian.dispose();
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
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        guardianName:
            _guardian.text.trim().isEmpty ? null : _guardian.text.trim(),
        dateOfJoining: DateTime.now(),
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
        icon: Icons.person_add_alt_1_rounded,
        title: 'Add a customer',
        subtitle: 'A bed can be assigned right after',
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
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _phone,
            enabled: !_saving,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _guardian,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              labelText: 'Guardian name (optional)',
              prefixIcon: Icon(Icons.family_restroom_rounded),
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
                : const Text('Add customer'),
          ),
        ],
      ),
    );
  }
}
