import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../bed/bed_models.dart';
import '../bed/bed_repository.dart';
import '../floor/floor_models.dart';
import 'room_models.dart';
import 'room_repository.dart';

class RoomListScreen extends StatefulWidget {
  final String floorId;
  final Floor? floor;

  const RoomListScreen({super.key, required this.floorId, this.floor});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final _roomRepository = RoomRepository();
  final _bedRepository = BedRepository();
  late Future<List<Room>> _future;

  @override
  void initState() {
    super.initState();
    _future = _roomRepository.listForFloor(widget.floorId);
  }

  void _reload() =>
      setState(() => _future = _roomRepository.listForFloor(widget.floorId));

  Future<void> _openCreateDialog() async {
    final roomNumberController = TextEditingController();
    final sharingController = TextEditingController(text: '1');
    final rentController = TextEditingController();
    final dayRateController = TextEditingController();
    final depositController = TextEditingController(text: '0');
    final noticeController = TextEditingController(text: '15');
    var roomType = RoomType.nonAc;
    var bookingMode = RoomBookingMode.monthly;
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add a room'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(error!,
                        style: const TextStyle(color: AppColors.danger)),
                  ),
                TextField(
                  controller: roomNumberController,
                  decoration: const InputDecoration(labelText: 'Room number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sharingController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Number of beds'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Monthly rent per bed', prefixText: '₹ '),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoomType>(
                  initialValue: roomType,
                  decoration: const InputDecoration(labelText: 'Room type'),
                  items: RoomType.values
                      .map((type) => DropdownMenuItem(
                          value: type, child: Text(type.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => roomType = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoomBookingMode>(
                  initialValue: bookingMode,
                  decoration: const InputDecoration(labelText: 'Booking availability'),
                  items: RoomBookingMode.values
                      .map((mode) => DropdownMenuItem(value: mode, child: Text(mode.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => bookingMode = value);
                  },
                ),
                if (bookingMode != RoomBookingMode.monthly) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: dayRateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Day-wise rate per bed', prefixText: '₹ '),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: depositController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monthly security deposit', prefixText: '₹ '),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noticeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Move-out notice days'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await _roomRepository.create(
                    floorId: widget.floorId,
                    roomNumber: roomNumberController.text.trim(),
                    sharingCount:
                        int.tryParse(sharingController.text.trim()) ?? 1,
                    rentPerBed:
                        double.tryParse(rentController.text.trim()) ?? 0,
                    roomType: roomType,
                    bookingMode: bookingMode,
                    dayWiseRate: bookingMode == RoomBookingMode.monthly
                        ? null : double.tryParse(dayRateController.text.trim()),
                    noticePeriodDays: int.tryParse(noticeController.text.trim()) ?? 15,
                    securityDeposit: double.tryParse(depositController.text.trim()) ?? 0,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Create room'),
            ),
          ],
        ),
      ),
    );
    if (created == true) _reload();
  }

  Future<void> _setBedStatus(Bed bed, BedStatus next) async {
    try {
      await _bedRepository.updateStatus(bed.id, next);
      if (mounted) {
        Navigator.of(context).pop();
      }
      _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _setBedBookingMode(Bed bed, BedBookingMode next) async {
    try {
      await _bedRepository.updateBookingMode(bed.id, next);
      if (mounted) Navigator.of(context).pop();
      _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Color _bedColor(BedStatus status) {
    return switch (status) {
      BedStatus.available => AppColors.success,
      BedStatus.occupied => AppColors.ink,
      BedStatus.maintenance => AppColors.warning,
    };
  }

  IconData _bedIcon(BedStatus status) {
    return switch (status) {
      BedStatus.available => Icons.bed_outlined,
      BedStatus.occupied => Icons.person_rounded,
      BedStatus.maintenance => Icons.build_outlined,
    };
  }

  void _openBedSheet(Bed bed, Room room) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        final color = _bedColor(bed.status);
        final occupant = bed.occupant;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_bedIcon(bed.status), color: color),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bed.label,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text(bed.status.label,
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (occupant != null) ...[
                  const Divider(height: 30),
                  Text('Occupant details',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 13),
                  _detailRow(
                      Icons.person_outline, 'Customer', occupant.fullName),
                  _detailRow(Icons.call_outlined, 'Phone', occupant.phone),
                  if (occupant.guardianName != null &&
                      occupant.guardianName!.isNotEmpty)
                    _detailRow(
                      Icons.family_restroom_rounded,
                      'Guardian',
                      '${occupant.guardianName}${occupant.guardianPhone != null ? ' · ${occupant.guardianPhone}' : ''}',
                    ),
                  _detailRow(Icons.calendar_today_outlined, 'Joined',
                      occupant.dateOfJoining),
                ],
                const Divider(height: 30),
                Text('Booking type', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(bed.bookingMode.label, style: TextStyle(color: bed.bookingMode == BedBookingMode.monthly
                    ? const Color(0xFF7B61FF)
                    : bed.bookingMode == BedBookingMode.dayWise
                        ? const Color(0xFF2F80ED)
                        : const Color(0xFF1B998B), fontWeight: FontWeight.w700)),
                if (room.bookingMode == RoomBookingMode.mixed) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: BedBookingMode.values.map((mode) => ChoiceChip(
                      label: Text(mode.label),
                      selected: bed.bookingMode == mode,
                      onSelected: (_) => _setBedBookingMode(bed, mode),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: bed.status == BedStatus.available
                      ? OutlinedButton.icon(
                          onPressed: () =>
                              _setBedStatus(bed, BedStatus.maintenance),
                          icon: const Icon(Icons.build_outlined),
                          label: const Text('Mark as maintenance'),
                        )
                      : OutlinedButton.icon(
                          onPressed: () =>
                              _setBedStatus(bed, BedStatus.available),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Mark as available'),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 1),
                Text(label,
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rooms & beds')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add room'),
      ),
      body: FutureBuilder<List<Room>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Rooms could not be loaded.';
            return _RoomMessageState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load rooms',
              message: message,
              actionLabel: 'Try again',
              onAction: _reload,
            );
          }

          final rooms = snapshot.data ?? [];
          if (rooms.isEmpty) {
            return const _RoomMessageState(
              icon: Icons.meeting_room_outlined,
              title: 'No rooms added',
              message:
                  'Create a room and its bed spaces will be added automatically.',
            );
          }

          final allBeds = rooms.expand((room) => room.beds).toList();
          final availableCount =
              allBeds.where((bed) => bed.status == BedStatus.available).length;
          final occupiedCount =
              allBeds.where((bed) => bed.status == BedStatus.occupied).length;
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              itemCount: rooms.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _FloorSummary(
                    name: widget.floor?.name ?? 'Floor overview',
                    roomCount: rooms.length,
                    availableCount: availableCount,
                    occupiedCount: occupiedCount,
                  );
                }
                final room = rooms[index - 1];
                final available = room.beds
                    .where((bed) => bed.status == BedStatus.available)
                    .length;
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    collapsedShape: const Border(),
                    shape: const Border(),
                    leading: Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                          color: AppColors.fill,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.meeting_room_outlined,
                          color: AppColors.ink, size: 22),
                    ),
                    title: Text('Room ${room.roomNumber}',
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(
                      '${room.roomType.label} · ${room.bookingMode.label} · ₹${room.rentPerBed.toStringAsFixed(0)}/bed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$available free',
                          style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700),
                        ),
                        const Icon(Icons.expand_more_rounded,
                            color: AppColors.muted, size: 20),
                      ],
                    ),
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/owner/rooms/${room.id}/calendar', extra: room),
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: const Text('Open booking calendar'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Bed layout',
                            style: Theme.of(context).textTheme.labelLarge),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final bedWidth = (constraints.maxWidth - 18) / 3;
                          return Wrap(
                            spacing: 9,
                            runSpacing: 9,
                            children: room.beds.map((bed) {
                              final color = _bedColor(bed.status);
                              return SizedBox(
                                width: bedWidth,
                                height: 94,
                                child: Material(
                                  color: color.withValues(alpha: 0.08),
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(
                                        color: color.withValues(alpha: 0.35)),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () => _openBedSheet(bed, room),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 8),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(_bedIcon(bed.status),
                                              color: color, size: 22),
                                          const SizedBox(height: 4),
                                          Text(
                                            bed.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: color),
                                          ),
                                          Text(
                                            bed.status.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: AppColors.muted),
                                          ),
                                          Text(
                                            bed.bookingMode.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 8, color: AppColors.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _legendDot(AppColors.success, 'Available'),
                          _legendDot(AppColors.ink, 'Occupied'),
                          _legendDot(AppColors.warning, 'Maintenance'),
                        ],
                      ),
                    ],
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

class _FloorSummary extends StatelessWidget {
  final String name;
  final int roomCount;
  final int availableCount;
  final int occupiedCount;

  const _FloorSummary({
    required this.name,
    required this.roomCount,
    required this.availableCount,
    required this.occupiedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryValue(
                  value: '$roomCount', label: 'Rooms', color: AppColors.ink),
              const SizedBox(width: 24),
              _SummaryValue(
                  value: '$availableCount',
                  label: 'Available',
                  color: AppColors.success),
              const SizedBox(width: 24),
              _SummaryValue(
                  value: '$occupiedCount',
                  label: 'Occupied',
                  color: AppColors.ink),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryValue(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RoomMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _RoomMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: AppColors.fill, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.ink, size: 30),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
