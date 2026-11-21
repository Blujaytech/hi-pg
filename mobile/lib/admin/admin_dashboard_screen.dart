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
import 'admin_notifications_panel.dart';
import 'admin_pg_listings_panel.dart';
import 'admin_support_panel.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AdminKycRepository? kycRepository;
  final Widget? listingsPanel;
  final Widget? supportPanel;
  final Widget? notificationsPanel;

  const AdminDashboardScreen({
    super.key,
    this.kycRepository,
    this.listingsPanel,
    this.supportPanel,
    this.notificationsPanel,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AdminKycRepository _repository;
  late final TabController _tabController;
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
    _repository = widget.kycRepository ?? AdminKycRepository();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_handleTabChange);
    _load();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  void _selectSection(int index) {
    _tabController.animateTo(index);
    setState(() {});
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
    final expanded = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;
    final pages = [
      _buildKycPanel(),
      widget.listingsPanel ?? const AdminPgListingsPanel(),
      widget.supportPanel ?? const AdminSupportPanel(),
      widget.notificationsPanel ?? const AdminNotificationsPanel(),
    ];
    final pageView = TabBarView(
      controller: _tabController,
      physics: expanded ? const NeverScrollableScrollPhysics() : null,
      children: pages,
    );
    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(
          title: 'Admin dashboard',
          subtitle: 'Reviews, listings and support',
        ),
        bottom: expanded
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: AppColors.brand,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(icon: Icon(Icons.fact_check_outlined), text: 'KYC'),
                  Tab(icon: Icon(Icons.add_business_outlined), text: 'PGs'),
                  Tab(
                      icon: Icon(Icons.support_agent_outlined),
                      text: 'Support'),
                  Tab(icon: Icon(Icons.send_outlined), text: 'Messages'),
                ],
              ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: expanded
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tabController.index,
                  onDestinationSelected: _selectSection,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: AppColors.surface,
                  indicatorColor: AppColors.brandSoft,
                  selectedIconTheme:
                      const IconThemeData(color: AppColors.brandText),
                  selectedLabelTextStyle: const TextStyle(
                    color: AppColors.brandText,
                    fontWeight: FontWeight.w700,
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.fact_check_outlined),
                      selectedIcon: Icon(Icons.fact_check_rounded),
                      label: Text('KYC reviews'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.add_business_outlined),
                      selectedIcon: Icon(Icons.add_business_rounded),
                      label: Text('PG listings'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.support_agent_outlined),
                      selectedIcon: Icon(Icons.support_agent_rounded),
                      label: Text('Support'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.send_outlined),
                      selectedIcon: Icon(Icons.send_rounded),
                      label: Text('Messages'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pageView),
              ],
            )
          : pageView,
    );
  }

  Widget _buildKycPanel() {
    if (_loading) {
      return const AppLoadingView(label: 'Loading KYC submissions...');
    }
    if (_error != null && _submissions.isEmpty) {
      return AppErrorView(message: _error!, onRetry: _load);
    }
    final pending = _count(OwnerKycStatus.submitted);
    final verified = _count(OwnerKycStatus.verified);
    final returned = _count(OwnerKycStatus.rejected);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        children: [
          Text('Owner verification queue',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text('Review identity documents before enabling owner payments.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AdminMetric(
                  label: 'Pending',
                  value: pending,
                  icon: Icons.schedule_rounded,
                  tone: StatusTone.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AdminMetric(
                  label: 'Verified',
                  value: verified,
                  icon: Icons.verified_outlined,
                  tone: StatusTone.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AdminMetric(
                  label: 'Returned',
                  value: returned,
                  icon: Icons.undo_rounded,
                  tone: StatusTone.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const AppMessageBanner(
            icon: Icons.admin_panel_settings_outlined,
            message:
                'Owner mobile numbers are already verified by OTP. Review the PG owner identity and uploaded documents here.',
          ),
          const SizedBox(height: 12),
          const AppMessageBanner(
            icon: Icons.lock_outline_rounded,
            message:
                'KYC files remain private. Each document button creates a time-limited review link.',
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
              _chip('Pending ($pending)', OwnerKycStatus.submitted),
              _chip('Verified ($verified)', OwnerKycStatus.verified),
              _chip('Returned ($returned)', OwnerKycStatus.rejected),
              _chip('All (${_submissions.length})', null),
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
    );
  }

  int _count(OwnerKycStatus status) =>
      _submissions.where((item) => item.status == status).length;

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
            _line(Icons.phone_outlined, 'Owner mobile (optional)',
                item.verifiedPhone ?? 'Not provided'),
            if ((item.reviewNote ?? '').isNotEmpty)
              _line(Icons.notes_rounded, 'Review note', item.reviewNote!),
            const Divider(height: 28),
            Text(
                'Documents (${item.documents.where((document) => document.type != OwnerKycDocumentType.pgPhoto).length}/4)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final document in item.documents.where(
                (document) => document.type != OwnerKycDocumentType.pgPhoto))
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

class _AdminMetric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final StatusTone tone;

  const _AdminMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (tone) {
      StatusTone.success => (AppColors.success, AppColors.successSoft),
      StatusTone.warning => (AppColors.warning, AppColors.warningSoft),
      StatusTone.danger => (AppColors.danger, AppColors.dangerSoft),
      _ => (AppColors.ink, AppColors.fill),
    };
    return AppSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: icon,
            size: 34,
            color: color,
            background: background,
          ),
          const SizedBox(height: 10),
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
