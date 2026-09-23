import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_state.dart';
import '../core/api_exception.dart';
import '../core/theme.dart';
import '../owner/onboarding/owner_kyc_models.dart';
import '../shared/app_states.dart';
import 'admin_kyc_repository.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _repository = AdminKycRepository();
  List<OwnerKycSubmission> _submissions = const [];
  OwnerKycStatus? _filter = OwnerKycStatus.submitted;
  bool _loading = true;
  bool _working = false;
  String? _error;

  List<OwnerKycSubmission> get _visible => _filter == null
      ? _submissions
      : _submissions.where((item) => item.status == _filter).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final submissions = await _repository.listAll();
      if (mounted) setState(() => _submissions = submissions);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'The KYC queue could not be loaded.';

  Future<void> _openDocument(OwnerKycDocument document) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final url = await _repository.documentUrl(document.id);
      final opened =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('Could not open the document.');
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _approve(OwnerKycSubmission submission) async {
    final linkedAccount = TextEditingController();
    final commission = TextEditingController(text: '0');
    final note = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve KYC'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Approval enables direct owner UPI payments. Razorpay is optional and can be linked separately.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: linkedAccount,
                decoration: const InputDecoration(
                  labelText: 'Razorpay linked account (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commission,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Platform commission (basis points)',
                  helperText: '100 basis points = 1%',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Review note (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (result == true) {
      final bps = int.tryParse(commission.text.trim());
      if (bps == null || bps < 0 || bps > 10000) {
        if (mounted) {
          setState(() =>
              _error = 'Commission must be from 0 to 10000 basis points.');
        }
      } else {
        await _review(
          submission: submission,
          status: OwnerKycStatus.verified,
          commissionBps: bps,
          linkedAccount: linkedAccount.text,
          note: note.text,
        );
      }
    }
    linkedAccount.dispose();
    commission.dispose();
    note.dispose();
  }

  Future<void> _reject(OwnerKycSubmission submission) async {
    final reason = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return KYC for changes'),
        content: TextField(
          controller: reason,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            helperText: 'The owner will see this message.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Return')),
        ],
      ),
    );
    if (result == true) {
      if (reason.text.trim().isEmpty) {
        if (mounted) {
          setState(
              () => _error = 'Enter a clear rejection reason for the owner.');
        }
      } else {
        await _review(
          submission: submission,
          status: OwnerKycStatus.rejected,
          commissionBps: 0,
          note: reason.text,
        );
      }
    }
    reason.dispose();
  }

  Future<void> _review({
    required OwnerKycSubmission submission,
    required OwnerKycStatus status,
    required int commissionBps,
    String? linkedAccount,
    String? note,
  }) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final updated = await _repository.review(
        submissionId: submission.id,
        status: status,
        platformCommissionBps: commissionBps,
        razorpayLinkedAccountId: linkedAccount,
        reviewNote: note,
      );
      if (!mounted) return;
      setState(() {
        _submissions = [
          for (final item in _submissions)
            if (item.id == updated.id) updated else item,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(status == OwnerKycStatus.verified
                ? 'KYC approved. Direct owner payments are now available.'
                : 'KYC returned to the owner for changes.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthState>().logout();
    if (mounted) context.go('/owner/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC administration'),
        actions: [
          IconButton(
            tooltip: 'Owner workspace',
            onPressed: () => context.go('/owner'),
            icon: const Icon(Icons.business_outlined),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingView(label: 'Loading KYC submissions...')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                children: [
                  const AppMessageBanner(
                    icon: Icons.admin_panel_settings_outlined,
                    message:
                        'Admin access only. Owner mobile numbers are already verified by OTP; review the PG owner identity and uploaded documents here.',
                  ),
                  const SizedBox(height: 12),
                  const AppMessageBanner(
                    icon: Icons.lock_outline_rounded,
                    message:
                        'KYC metadata is stored in PostgreSQL. Files stay in private object storage and each document button creates a 10-minute signed review link.',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AppMessageBanner(
                      icon: Icons.error_outline_rounded,
                      message: _error!,
                      color: AppColors.danger,
                      background: AppColors.dangerSoft,
                    ),
                  ],
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _chip('Pending', OwnerKycStatus.submitted),
                      _chip('Verified', OwnerKycStatus.verified),
                      _chip('Returned', OwnerKycStatus.rejected),
                      _chip('All', null),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  if (_visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 52),
                      child: AppEmptyView(
                        icon: Icons.fact_check_outlined,
                        title: 'No KYC submissions',
                        message: 'There are no records in this filter.',
                      ),
                    )
                  else
                    for (final submission in _visible) ...[
                      _submissionCard(submission),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
            ),
    );
  }

  Widget _chip(String label, OwnerKycStatus? value) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );

  Widget _submissionCard(OwnerKycSubmission item) {
    final (label, tone) = switch (item.status) {
      OwnerKycStatus.submitted => ('Pending review', StatusTone.warning),
      OwnerKycStatus.verified => ('Verified', StatusTone.success),
      OwnerKycStatus.rejected => ('Returned', StatusTone.danger),
      _ => ('Draft', StatusTone.neutral),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child: Text(item.pgName,
                      style: Theme.of(context).textTheme.titleMedium)),
              StatusPill(label: label, tone: tone),
            ]),
            const SizedBox(height: 12),
            _line(Icons.person_outline_rounded, 'Owner', item.ownerName),
            _line(Icons.badge_outlined, 'Legal name', item.legalName),
            _line(Icons.phone_outlined, 'OTP verified mobile',
                item.verifiedPhone ?? 'Missing'),
            _line(Icons.credit_card_outlined, 'PAN / Aadhaar',
                '••••${item.panLastFour}  /  ••••${item.aadhaarLastFour}'),
            if ((item.reviewNote ?? '').isNotEmpty)
              _line(Icons.notes_rounded, 'Review note', item.reviewNote!),
            const Divider(height: 28),
            Text('Documents (${item.documents.length}/5)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final document in item.documents)
              TextButton.icon(
                onPressed: _working ? null : () => _openDocument(document),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('${document.type.label} · ${document.fileName}'),
              ),
            if (item.status == OwnerKycStatus.submitted) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _working ? null : () => _reject(item),
                    child: const Text('Return'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _working ? null : () => _approve(item),
                    child: const Text('Approve'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text('$label: $value')),
        ]),
      );
}
