import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../notification/notification_models.dart';
import '../shared/api_client.dart';
import '../shared/app_states.dart';

enum _MessageAudience { direct, owners, students, all }

class AdminNotificationsPanel extends StatefulWidget {
  const AdminNotificationsPanel({super.key});

  @override
  State<AdminNotificationsPanel> createState() =>
      _AdminNotificationsPanelState();
}

class _AdminNotificationsPanelState extends State<AdminNotificationsPanel> {
  final _formKey = GlobalKey<FormState>();
  final _recipients = TextEditingController();
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _route = TextEditingController(text: '/notifications');
  _MessageAudience _audience = _MessageAudience.direct;
  AppNotificationCategory _category = AppNotificationCategory.general;
  bool _sending = false;
  String? _result;

  @override
  void dispose() {
    _recipients.dispose();
    _title.dispose();
    _message.dispose();
    _route.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate() || _sending) return;
    if (_audience == _MessageAudience.all) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Message every active account?'),
          content: const Text(
            'This creates an inbox item and sends push notifications to every registered device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send to everyone'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      _sending = true;
      _result = null;
    });
    try {
      final recipients = _recipients.text
          .split(RegExp(r'[,\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/admin/notifications',
        data: {
          'audience': _audience.name.toUpperCase(),
          'recipients': recipients,
          'title': _title.text.trim(),
          'message': _message.text.trim(),
          'category': _category.apiValue,
          'actionRoute': _route.text.trim().isEmpty ? null : _route.text.trim(),
        },
      );
      final data = response.data!;
      final unresolved =
          (data['unresolvedRecipients'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList();
      if (!mounted) return;
      setState(() {
        _result =
            '${data['recipients']} inbox deliveries · ${data['pushDevices']} push devices'
            '${unresolved.isEmpty ? '' : ' · Not found: ${unresolved.join(', ')}'}';
        _title.clear();
        _message.clear();
      });
    } catch (error) {
      if (mounted) {
        setState(() => _result = error is ApiException
            ? error.message
            : 'The message could not be sent.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COMMUNICATIONS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
            ),
            const SizedBox(height: 6),
            Text('Send a direct update',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Messages remain in the recipient inbox and also use FCM when a device is registered.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: AppSurface(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<_MessageAudience>(
                  initialValue: _audience,
                  decoration: const InputDecoration(labelText: 'Audience'),
                  items: const [
                    DropdownMenuItem(
                        value: _MessageAudience.direct,
                        child: Text('Specific accounts')),
                    DropdownMenuItem(
                        value: _MessageAudience.owners,
                        child: Text('All PG owners')),
                    DropdownMenuItem(
                        value: _MessageAudience.students,
                        child: Text('All customers')),
                    DropdownMenuItem(
                        value: _MessageAudience.all,
                        child: Text('Every active account')),
                  ],
                  onChanged: (value) => setState(() => _audience = value!),
                ),
                if (_audience == _MessageAudience.direct) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _recipients,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Email, mobile or user ID',
                      helperText: 'Separate multiple recipients with commas.',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter at least one recipient.'
                        : null,
                  ),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<AppNotificationCategory>(
                  initialValue: _category,
                  decoration:
                      const InputDecoration(labelText: 'Message category'),
                  items: AppNotificationCategory.values
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name[0].toUpperCase() +
                                value.name.substring(1)),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _category = value!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title.'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _message,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: 'Message'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a message.'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _route,
                  decoration: const InputDecoration(
                    labelText: 'Open app route',
                    helperText: 'Use an internal path such as /notifications.',
                  ),
                  validator: (value) {
                    final route = value?.trim() ?? '';
                    return route.isNotEmpty && !route.startsWith('/')
                        ? 'The route must begin with /.'
                        : null;
                  },
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'Sending…' : 'Send message'),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 14),
                  Text(_result!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const AppSurface(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.brand),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Owners who have not installed and signed in to HiPG still require an SMS invitation. Use the PG listings tab to inspect and retry that delivery.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
