import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../owner/complaint/complaint_models.dart';
import '../../owner/complaint/complaint_visuals.dart';
import '../../shared/app_states.dart';
import 'student_complaint_repository.dart';

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  final _repository = StudentComplaintRepository();
  late Future<List<Complaint>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listMine();
  }

  void _reload() => setState(() => _future = _repository.listMine());

  Future<void> _openNewComplaint() async {
    final created = await showFormSheet<bool>(
      context,
      (context) => _NewComplaintSheet(repository: _repository),
    );
    if (created == true && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support request submitted successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Complaint>>(
      future: _future,
      builder: (context, snapshot) => Scaffold(
        appBar: AppBar(title: const Text('Help & support')),
        floatingActionButton: snapshot.hasData && snapshot.data!.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _openNewComplaint,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New request'),
              )
            : null,
        body: _buildBody(snapshot),
      ),
    );
  }

  Widget _buildBody(AsyncSnapshot<List<Complaint>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const AppLoadingView(label: 'Loading your requests...');
    }
    if (snapshot.hasError) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : 'Check your connection and try again.';
      if (snapshot.error is ApiException &&
          (snapshot.error as ApiException).statusCode == 404) {
        return AppEmptyView(
          icon: Icons.home_work_outlined,
          title: 'Book a stay first',
          message:
              'Support requests are connected to your PG. Once you have a booking, you can contact the property team here.',
          actionLabel: 'Back to home',
          onAction: () => Navigator.of(context).pop(),
        );
      }
      return AppErrorView(message: message, onRetry: _reload);
    }

    final complaints = snapshot.data ?? const <Complaint>[];
    if (complaints.isEmpty) {
      return AppEmptyView(
        icon: Icons.support_agent_rounded,
        title: 'No support requests',
        message:
            'Need help with maintenance, billing, cleanliness, or safety? Send a request and track every update here.',
        actionLabel: 'Create a request',
        actionIcon: Icons.add_rounded,
        onAction: _openNewComplaint,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        try {
          await _future;
        } catch (_) {
          // The FutureBuilder renders the error state.
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            sliver: SliverToBoxAdapter(
              child: _ComplaintOverview(complaints: complaints),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
            sliver: SliverList.separated(
              itemCount: complaints.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _ComplaintCard(complaint: complaints[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintOverview extends StatelessWidget {
  final List<Complaint> complaints;

  const _ComplaintOverview({required this.complaints});

  @override
  Widget build(BuildContext context) {
    final active = complaints
        .where((item) =>
            item.status == ComplaintStatus.open ||
            item.status == ComplaintStatus.inProgress)
        .length;
    final resolved = complaints.length - active;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Property support',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active == 0
                      ? 'Everything is currently resolved.'
                      : '$active request${active == 1 ? '' : 's'} need attention.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .66),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          _OverviewCount(value: active, label: 'Active'),
          const SizedBox(width: 8),
          _OverviewCount(value: resolved, label: 'Resolved'),
        ],
      ),
    );
  }
}

class _OverviewCount extends StatelessWidget {
  final int value;
  final String label;

  const _OverviewCount({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .66),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Complaint complaint;

  const _ComplaintCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d MMM yyyy, h:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(icon: complaint.category.icon, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complaint.category.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${complaint.pgName}  ·  ${formatter.format(complaint.createdAt.toLocal())}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: complaint.status.label,
                  tone: complaint.status.tone,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              complaint.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.flag_rounded,
                    size: 15, color: complaint.priority.color),
                const SizedBox(width: 5),
                Text(
                  '${complaint.priority.label} priority',
                  style: TextStyle(
                    color: complaint.priority.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (complaint.resolutionNotes != null &&
                complaint.resolutionNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.task_alt_rounded,
                            color: AppColors.success, size: 17),
                        SizedBox(width: 6),
                        Text(
                          'Resolution update',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      complaint.resolutionNotes!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewComplaintSheet extends StatefulWidget {
  final StudentComplaintRepository repository;

  const _NewComplaintSheet({required this.repository});

  @override
  State<_NewComplaintSheet> createState() => _NewComplaintSheetState();
}

class _NewComplaintSheetState extends State<_NewComplaintSheet> {
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

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.create(
        category: _category,
        priority: _priority,
        description: _description.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: FormSheet(
        icon: Icons.support_agent_rounded,
        title: 'How can we help?',
        subtitle: 'Your request goes directly to the property owner.',
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
              labelText: 'Request category',
              prefixIcon: Icon(_category.icon),
            ),
            items: ComplaintCategory.values
                .map((category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ))
                .toList(),
            onChanged: _saving
                ? null
                : (value) => setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 18),
          Text('Priority', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          SegmentedButton<ComplaintPriority>(
            segments: ComplaintPriority.values
                .map((priority) => ButtonSegment(
                      value: priority,
                      label: Text(priority.label),
                    ))
                .toList(),
            selected: {_priority},
            onSelectionChanged: _saving
                ? null
                : (value) => setState(() => _priority = value.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _description,
            enabled: !_saving,
            minLines: 4,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Describe the issue',
              alignLabelWithHint: true,
              hintText: 'Include the room or area and what needs attention.',
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Please describe the issue';
              if (text.length < 10) return 'Add a little more detail';
              return null;
            },
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_saving ? 'Submitting...' : 'Submit request'),
          ),
        ],
      ),
    );
  }
}
