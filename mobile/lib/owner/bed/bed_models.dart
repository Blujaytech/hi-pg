enum BedStatus { available, occupied, maintenance }

enum BedBookingMode { monthly, dayWise, flexible }

extension BedBookingModeX on BedBookingMode {
  String get apiValue => switch (this) {
    BedBookingMode.monthly => 'MONTHLY',
    BedBookingMode.dayWise => 'DAY_WISE',
    BedBookingMode.flexible => 'FLEXIBLE',
  };
  String get label => switch (this) {
    BedBookingMode.monthly => 'Monthly',
    BedBookingMode.dayWise => 'Day-wise',
    BedBookingMode.flexible => 'Flexible',
  };
  static BedBookingMode fromApi(String value) => switch (value) {
    'DAY_WISE' => BedBookingMode.dayWise,
    'FLEXIBLE' => BedBookingMode.flexible,
    _ => BedBookingMode.monthly,
  };
}

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

class BedOccupant {
  final String studentId;
  final String fullName;
  final String phone;
  final String? guardianName;
  final String? guardianPhone;
  final String dateOfJoining;

  BedOccupant({
    required this.studentId,
    required this.fullName,
    required this.phone,
    required this.guardianName,
    required this.guardianPhone,
    required this.dateOfJoining,
  });

  factory BedOccupant.fromJson(Map<String, dynamic> json) => BedOccupant(
        studentId: json['studentId'] as String,
        fullName: json['fullName'] as String,
        phone: json['phone'] as String,
        guardianName: json['guardianName'] as String?,
        guardianPhone: json['guardianPhone'] as String?,
        dateOfJoining: json['dateOfJoining'] as String,
      );
}

class Bed {
  final String id;
  final String roomId;
  final String label;
  final BedStatus status;
  final BedBookingMode bookingMode;
  final BedOccupant? occupant;

  Bed({required this.id, required this.roomId, required this.label, required this.status,
    required this.bookingMode, this.occupant});

  factory Bed.fromJson(Map<String, dynamic> json) => Bed(
        id: json['id'] as String,
        roomId: json['roomId'] as String,
        label: json['label'] as String,
        status: BedStatusX.fromApi(json['status'] as String),
        bookingMode: BedBookingModeX.fromApi(json['bookingMode'] as String? ?? 'MONTHLY'),
        occupant: json['occupant'] != null ? BedOccupant.fromJson(json['occupant'] as Map<String, dynamic>) : null,
      );
}
