enum BedStatus { available, occupied, maintenance }

extension BedStatusX on BedStatus {
  String get apiValue => switch (this) {
        BedStatus.available => 'AVAILABLE',
        BedStatus.occupied => 'OCCUPIED',
        BedStatus.maintenance => 'MAINTENANCE',
      };

  String get label => switch (this) {
        BedStatus.available => 'Available',
        BedStatus.occupied => 'Occupied',
        BedStatus.maintenance => 'Maintenance',
      };

  static BedStatus fromApi(String value) => switch (value) {
        'OCCUPIED' => BedStatus.occupied,
        'MAINTENANCE' => BedStatus.maintenance,
        _ => BedStatus.available,
      };
}

class Bed {
  final String id;
  final String roomId;
  final String label;
  final BedStatus status;

  Bed({required this.id, required this.roomId, required this.label, required this.status});

  factory Bed.fromJson(Map<String, dynamic> json) => Bed(
        id: json['id'] as String,
        roomId: json['roomId'] as String,
        label: json['label'] as String,
        status: BedStatusX.fromApi(json['status'] as String),
      );
}
