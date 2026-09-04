import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../shared/api_client.dart';
import '../booking/booking_repository.dart';
import 'discovery_models.dart';
import 'discovery_repository.dart';

class PgDetailsScreen extends StatefulWidget {
  final String pgId;

  const PgDetailsScreen({super.key, required this.pgId});

  @override
  State<PgDetailsScreen> createState() => _PgDetailsScreenState();
}

class _PgDetailsScreenState extends State<PgDetailsScreen> {
  final _repository = DiscoveryRepository();
  final _bookingRepository = BookingRepository();
  late Future<PgDetails> _future;

  StreamSubscription<Map<String, dynamic>>? _availabilitySubscription;
  int? _liveAvailableBeds;
  int? _liveTotalBeds;
  bool _live = false;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _subscribeToLiveAvailability();
  }

  void _loadDetails() {
    _future = _repository.getDetails(widget.pgId);
  }

  /// Phase 10 -- PG-level live count only (matches the web app's scope
  /// decision, see docs/decisions.md): per-room availability still comes
  /// from the one-time fetch above and only refreshes on pull-to-refresh
  /// (or right after this screen's own booking attempt).
  void _subscribeToLiveAvailability() {
    _availabilitySubscription = ApiClient.instance.sseStream('/public/pgs/${widget.pgId}/availability/stream').listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _liveAvailableBeds = event['availableBeds'] as int?;
          _liveTotalBeds = event['totalBeds'] as int?;
          _live = true;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _live = false);
      },
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _availabilitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _bookBed(AvailableBedOption bed) async {
    final moveInDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      helpText: 'Move-in date for ${bed.label}',
    );
    if (moveInDate == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Book ${bed.label}?'),
        content: Text('Move-in date: ${moveInDate.toIso8601String().substring(0, 10)}\n\n'
            'This confirms the booking immediately and occupies the bed -- it does not need owner approval.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm booking')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _booking = true);
    try {
      await _bookingRepository.book(bedId: bed.id, moveInDate: moveInDate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${bed.label} booked! See My Bookings for details.')),
      );
      setState(_loadDetails);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PG Details')),
      body: FutureBuilder<PgDetails>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Failed to load PG';
            return Center(child: Text(message));
          }
          final pg = snapshot.data!;
          final availableBeds = _liveAvailableBeds ?? pg.availableBeds;
          final totalBeds = _liveTotalBeds ?? pg.totalBeds;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(pg.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('${pg.address}, ${pg.city}${pg.state != null ? ', ${pg.state}' : ''}'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                Chip(label: Text(pg.genderPreference.label)),
                Chip(
                  avatar: _live ? const Icon(Icons.circle, size: 10, color: Colors.green) : null,
                  label: Text('$availableBeds/$totalBeds beds available'),
                ),
              ]),
              if (pg.description != null) ...[
                const SizedBox(height: 12),
                Text(pg.description!),
              ],
              const SizedBox(height: 20),
              Text('Rooms & availability', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (pg.floors.isEmpty) const Text('No rooms have been set up yet.'),
              for (final floor in pg.floors) ...[
                Text(floor.name, style: Theme.of(context).textTheme.titleSmall),
                for (final room in floor.rooms)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Room ${room.roomNumber} (${room.roomType == 'AC' ? 'AC' : 'Non-AC'})'),
                              Text(
                                room.availableBeds > 0 ? '${room.availableBeds} available' : 'Full',
                                style: TextStyle(color: room.availableBeds > 0 ? Colors.green.shade700 : Colors.grey),
                              ),
                            ],
                          ),
                          Text('${room.sharingCount}-sharing • ₹${room.rentPerBed.toStringAsFixed(0)}/bed/mo',
                              style: Theme.of(context).textTheme.bodySmall),
                          if (room.availableBedOptions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: room.availableBedOptions
                                  .map((bed) => ActionChip(
                                        label: Text('Book ${bed.label}'),
                                        avatar: const Icon(Icons.event_seat, size: 16),
                                        onPressed: _booking ? null : () => _bookBed(bed),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}
