import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import '../room/room_models.dart';
import 'booking_calendar_models.dart';
import 'booking_calendar_repository.dart';

class BookingCalendarScreen extends StatefulWidget {
  final String roomId;
  final Room? room;
  const BookingCalendarScreen({super.key, required this.roomId, this.room});

  @override
  State<BookingCalendarScreen> createState() => _BookingCalendarScreenState();
}

class _BookingCalendarScreenState extends State<BookingCalendarScreen> {
  final _repository = BookingCalendarRepository();
  late DateTime _from;
  late Future<List<BookingCalendarEntry>> _future;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _from = DateTime(today.year, today.month, 1);
    _load();
  }

  void _load() {
    _future = _repository.list(widget.roomId, _from, DateTime(_from.year, _from.month + 2, 1));
  }

  void _changeMonth(int delta) {
    setState(() {
      _from = DateTime(_from.year, _from.month + delta, 1);
      _load();
    });
  }

  Color _color(BookingCalendarEntry entry) {
    if (entry.status == 'PAYMENT_PENDING') return const Color(0xFFF2B84B);
    if (entry.status == 'CANCELLED' || entry.status == 'EXPIRED') return AppColors.muted;
    return entry.bookingType == 'DAY_WISE' ? const Color(0xFF2F80ED) : const Color(0xFF7B61FF);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Room ${widget.room?.roomNumber ?? ''} calendar')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(children: [
            Row(children: [
              IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(child: Text(DateFormat('MMMM yyyy').format(_from), textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium)),
              IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
            ]),
            const Wrap(spacing: 16, runSpacing: 8, children: [
              _Legend(color: Color(0xFF7B61FF), label: 'Monthly'),
              _Legend(color: Color(0xFF2F80ED), label: 'Day-wise'),
              _Legend(color: Color(0xFFF2B84B), label: 'Payment hold'),
              _Legend(color: AppColors.muted, label: 'Unavailable'),
            ]),
          ]),
        ),
        Expanded(child: FutureBuilder<List<BookingCalendarEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingView(label: 'Loading bed calendar...');
            }
            if (snapshot.hasError) {
              return AppErrorView(
                message: snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Calendar could not be loaded.',
                onRetry: () => setState(_load),
              );
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const AppEmptyView(icon: Icons.event_available_rounded,
                title: 'No bookings in this period', message: 'All beds are free for the selected dates.');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final color = _color(entry);
                final end = entry.endDate == null ? 'Open-ended' : DateFormat('d MMM yyyy').format(entry.endDate!);
                return Card(child: ListTile(
                  leading: Container(width: 6, height: 50, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                  title: Text('${entry.bedLabel} · ${entry.customerName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${DateFormat('d MMM yyyy').format(entry.startDate)} → $end\n${entry.bookingType == 'DAY_WISE' ? 'Day-wise' : 'Monthly'} · ${entry.status.replaceAll('_', ' ')}'),
                  isThreeLine: true,
                ));
              },
            );
          },
        )),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5), Text(label, style: Theme.of(context).textTheme.bodySmall),
  ]);
}
