import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../shared/app_states.dart';
import '../shared/support/support_models.dart';
import '../shared/support/support_repository.dart';

class AdminSupportPanel extends StatefulWidget {
  const AdminSupportPanel({super.key});

  @override
  State<AdminSupportPanel> createState() => _AdminSupportPanelState();
}

class _AdminSupportPanelState extends State<AdminSupportPanel> {
  final _repository = AdminSupportRepository();
  late Future<List<SupportTicket>> _future;
  SupportStatus? _filter = SupportStatus.open;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _repository.listAll();
    });
  }

  Future<void> _respond(SupportTicket ticket) async {
    final updated = await showFormSheet<SupportTicket>(
      context,
      (_) => _AdminResponseSheet(repository: _repository, ticket: ticket),
    );
    if (updated != null && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Response sent to the requester.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupportTicket>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingView(label: 'Loading support requests...');
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return AppErrorView(
            message: error is ApiException
                ? error.message
                : 'The support queue could not be loaded.',
            onRetry: _reload,
          );
        }
        final tickets = snapshot.data ?? const <SupportTicket>[];
        final visible = _filter == null
            ? tickets
            : tickets.where((item) => item.status == _filter).toList();
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              const AppMessageBanner(
                icon: Icons.support_agent_rounded,
                message:
                    'Owner and customer platform-support requests appear here with their contact details. Respond clearly and update the status.',
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _chip('Open', SupportStatus.open),
                  _chip('In progress', SupportStatus.inProgress),
                  _chip('Resolved', SupportStatus.resolved),
                  _chip('All', null),
                ]),
              ),
              const SizedBox(height: 14),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 52),
                  child: AppEmptyView(
                    icon: Icons.inbox_outlined,
                    title: 'No support requests',
                    message: 'There are no requests in this filter.',
                  ),
                )
              else
                for (final ticket in visible) ...[
                  _AdminTicketCard(
                    ticket: ticket,
                    onTap: () => _respond(ticket),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, SupportStatus? value) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );
}

class _AdminTicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;

  const _AdminTicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM yyyy, h:mm a');
    final contact = (ticket.requesterPhone ?? '').trim().isNotEmpty
        ? ticket.requesterPhone!
        : ((ticket.requesterEmail ?? '').trim().isNotEmpty
            ? ticket.requesterEmail!
            : 'No contact provided');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                        '${ticket.requesterName} · ${ticket.requesterRole == 'OWNER' ? 'PG owner' : 'Customer'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusPill(
                    label: ticket.status.label, tone: ticket.status.tone),
              ]),
              const SizedBox(height: 12),
              Text(ticket.description,
                  maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 6, children: [
                _detail(Icons.category_outlined, ticket.category.label),
                _detail(Icons.contact_phone_outlined, contact),
                _detail(Icons.schedule_rounded,
                    date.format(ticket.createdAt.toLocal())),
              ]),
              if ((ticket.adminResponse ?? '').trim().isNotEmpty) ...[
                const Divider(height: 26),
                Text('Latest admin response',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(ticket.adminResponse!,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  ticket.status == SupportStatus.open
                      ? 'Respond'
                      : 'Update response',
                  style: const TextStyle(
                    color: AppColors.brandText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.muted),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ),
        ],
      );
}

class _AdminResponseSheet extends StatefulWidget {
  final AdminSupportRepository repository;
  final SupportTicket ticket;

  const _AdminResponseSheet({required this.repository, required this.ticket});

  @override
  State<_AdminResponseSheet> createState() => _AdminResponseSheetState();
}

class _AdminResponseSheetState extends State<_AdminResponseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _response =
      TextEditingController(text: widget.ticket.adminResponse ?? '');
  late SupportStatus _status = widget.ticket.status == SupportStatus.open
      ? SupportStatus.inProgress
      : widget.ticket.status;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.respond(
        ticketId: widget.ticket.id,
        status: _status,
        responseText: _response.text,
      );
      if (mounted) Navigator.pop(context, updated);
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
        icon: Icons.mark_email_read_outlined,
        title: 'Respond to request',
        subtitle: '${widget.ticket.requesterName} · ${widget.ticket.subject}',
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
          SegmentedButton<SupportStatus>(
            segments: const [
              ButtonSegment(
                  value: SupportStatus.inProgress, label: Text('In progress')),
              ButtonSegment(
                  value: SupportStatus.resolved, label: Text('Resolved')),
            ],
            selected: {_status},
            onSelectionChanged: _saving
                ? null
                : (values) => setState(() => _status = values.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _response,
            enabled: !_saving,
            minLines: 4,
            maxLines: 7,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Response to requester',
              alignLabelWithHint: true,
              hintText: 'Explain the action taken or the next step.',
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Enter a response';
              if (text.length < 3) return 'Enter a clear response';
              return null;
            },
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_saving ? 'Sending...' : 'Send response'),
          ),
        ],
      ),
    );
  }
}
