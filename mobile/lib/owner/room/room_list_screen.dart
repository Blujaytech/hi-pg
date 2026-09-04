import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
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

  void _reload() => setState(() => _future = _roomRepository.listForFloor(widget.floorId));

  Future<void> _openCreateDialog() async {
    final roomNumberController = TextEditingController();
    final sharingController = TextEditingController(text: '1');
    final rentController = TextEditingController();
    RoomType roomType = RoomType.nonAc;
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
                if (error != null) Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
                TextField(controller: roomNumberController, decoration: const InputDecoration(labelText: 'Room number')),
                const SizedBox(height: 12),
                TextField(
                  controller: sharingController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sharing count (beds)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rentController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Rent per bed (₹/month)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoomType>(
                  value: roomType,
                  decoration: const InputDecoration(labelText: 'Room type'),
                  items: RoomType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                  onChanged: (v) => setDialogState(() => roomType = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await _roomRepository.create(
                    floorId: widget.floorId,
                    roomNumber: roomNumberController.text.trim(),
                    sharingCount: int.tryParse(sharingController.text.trim()) ?? 1,
                    rentPerBed: double.tryParse(rentController.text.trim()) ?? 0,
                    roomType: roomType,
                  );
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Create (auto-creates beds)'),
            ),
          ],
        ),
      ),
    );
    if (created == true) _reload();
  }

  Future<void> _cycleBedStatus(Bed bed) async {
    final next = BedStatus.values[(bed.status.index + 1) % BedStatus.values.length];
    try {
      await _bedRepository.updateStatus(bed.id, next);
      _reload();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Color _bedColor(BedStatus status) {
    switch (status) {
      case BedStatus.available:
        return Colors.green;
      case BedStatus.occupied:
        return Colors.orange;
      case BedStatus.maintenance:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.floor?.name ?? 'Rooms')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Room'),
      ),
      body: FutureBuilder<List<Room>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rooms = snapshot.data ?? [];
          if (rooms.isEmpty) {
            return const Center(child: Text('No rooms yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final room = rooms[index];
              return Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.meeting_room_outlined),
                  title: Text('Room ${room.roomNumber} (${room.roomType.label})'),
                  subtitle: Text('${room.sharingCount}-sharing • ₹${room.rentPerBed.toStringAsFixed(0)}/bed/month'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: room.beds
                            .map((bed) => ActionChip(
                                  avatar: Icon(Icons.bed_outlined, color: _bedColor(bed.status), size: 18),
                                  label: Text('${bed.label} • ${bed.status.label}'),
                                  onPressed: () => _cycleBedStatus(bed),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
