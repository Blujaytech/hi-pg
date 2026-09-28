import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../app_states.dart';
import 'support_models.dart';
import 'support_repository.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _repository = SupportRepository();
  late Future<List<SupportTicket>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _repository.listMine();
    });
  }

  Future<void> _create() async {
    final created = await showFormSheet<bool>(
      context,
      (_) => _NewSupportTicketSheet(repository: _repository),
    );
    if (created == true && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Your support request was sent to the hi pg admin.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupportTicket>>(
      future: _future,
      builder: (context, snapshot) => Scaffold(
        appBar: AppBar(title: const Text('Help & support')),
        floatingActionButton: snapshot.hasData && snapshot.data!.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _create,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New request'),
              )
            : null,
        body: _body(snapshot),
      ),
    );
  }

  Widget _body(AsyncSnapshot<List<SupportTicket>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const AppLoadingView(label: 'Loading support requests...');
    }
    if (snapshot.hasError) {
      final error = snapshot.error;
      return AppErrorView(
        message: error is ApiException
            ? error.message
            : 'Support requests could not be loaded.',
        onRetry: _reload,
      );
    }
    final tickets = snapshot.data ?? const <SupportTicket>[];
    if (tickets.isEmpty) {
      return AppEmptyView(
        icon: Icons.support_agent_rounded,
        title: 'How can we help?',
        message:
            'Contact the hi pg admin for account, booking, payment, KYC, or technical assistance.',
        actionLabel: 'Create support request',
        actionIcon: Icons.add_rounded,
        onAction: _create,
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _future;
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        itemCount: tickets.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const AppMessageBanner(
              icon: Icons.info_outline_rounded,
              message:
                  'These requests go to the hi pg admin. PG maintenance and stay issues should be raised as a complaint.',
            );
          }
          return _SupportTicketCard(ticket: tickets[index - 1]);
        },
      ),
    );
  }
}

class _SupportTicketCard extends StatelessWidget {
  final SupportTicket ticket;

  const _SupportTicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM yyyy, h:mm a');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconTile(icon: ticket.category.icon, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ticket.subject,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${ticket.category.label} · ${date.format(ticket.createdAt.toLocal())}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: ticket.status.label, tone: ticket.status.tone),
            ]),
            const SizedBox(height: 13),
            Text(ticket.description),
            if ((ticket.adminResponse ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Admin response',
                        style: TextStyle(
                            color: AppColors.brandText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(ticket.adminResponse!),
                    if (ticket.respondedAt != null) ...[
                      const SizedBox(height: 5),
                      Text(date.format(ticket.respondedAt!.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
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

class _NewSupportTicketSheet extends StatefulWidget {
  final SupportRepository repository;

  const _NewSupportTicketSheet({required this.repository});

  @override
  State<_NewSupportTicketSheet> createState() => _NewSupportTicketSheetState();
}

class _NewSupportTicketSheetState extends State<_NewSupportTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  SupportCategory _category = SupportCategory.account;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
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
        subject: _subject.text,
        description: _description.text,
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
        title: 'Contact hi pg support',
        subtitle: 'Give the admin enough detail to investigate and respond.',
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
          DropdownButtonFormField<SupportCategory>(
            initialValue: _category,
            decoration: InputDecoration(
              labelText: 'What do you need help with?',
              prefixIcon: Icon(_category.icon),
            ),
            items: SupportCategory.values
                .map((item) =>
                    DropdownMenuItem(value: item, child: Text(item.label)))
                .toList(),
            onChanged: _saving
                ? null
                : (value) => setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _subject,
            enabled: !_saving,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Subject',
              hintText: 'Short summary of the problem',
              prefixIcon: Icon(Icons.short_text_rounded),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Enter a subject';
              if (text.length < 5) return 'Add a clearer subject';
              return null;
            },
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _description,
            enabled: !_saving,
            minLines: 4,
            maxLines: 7,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Details',
              alignLabelWithHint: true,
              hintText:
                  'Explain what happened and include any booking or payment reference.',
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Enter the request details';
              if (text.length < 10) return 'Please add more detail';
              return null;
            },
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_saving ? 'Sending...' : 'Send to admin'),
          ),
        ],
      ),
    );
  }
}
