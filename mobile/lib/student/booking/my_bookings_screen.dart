import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import 'booking_models.dart';
import 'booking_repository.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _repository = BookingRepository();
  late Future<List<Booking>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listMine();
  }

  void _reload() => setState(() => _future = _repository.listMine());

  Future<void> _confirmCancel(Booking booking) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel booking for ${booking.bedLabel}?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep booking')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repository.cancel(booking.id, reason: reasonController.text.isEmpty ? null : reasonController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled')));
      _reload();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Failed to load bookings';
            return Center(child: Text(message));
          }
          final bookings = snapshot.data!;
          if (bookings.isEmpty) {
            return const Center(child: Text('No bookings yet. Find a PG and book a bed to get started.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final isConfirmed = booking.status == BookingStatus.confirmed;
                return Card(
                  child: ListTile(
                    leading: Icon(isConfirmed ? Icons.event_available : Icons.event_busy,
                        color: isConfirmed ? Colors.green.shade700 : Colors.grey),
                    title: Text('${booking.pgName} — ${booking.bedLabel} (Room ${booking.roomNumber})'),
                    subtitle: Text(
                      'Move-in ${booking.moveInDate.toIso8601String().substring(0, 10)} • ${booking.status.label}'
                      '${booking.cancellationReason != null ? ' — ${booking.cancellationReason}' : ''}',
                    ),
                    trailing: isConfirmed
                        ? TextButton(onPressed: () => _confirmCancel(booking), child: const Text('Cancel'))
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
