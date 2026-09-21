import '../bed/bed_models.dart';

enum RoomType { nonAc, ac }

enum RoomBookingMode { monthly, dayWise, mixed }

extension RoomBookingModeX on RoomBookingMode {
  String get apiValue => switch (this) {
    RoomBookingMode.monthly => 'MONTHLY',
    RoomBookingMode.dayWise => 'DAY_WISE',
    RoomBookingMode.mixed => 'MIXED',
  };
  String get label => switch (this) {
    RoomBookingMode.monthly => 'Monthly only',
    RoomBookingMode.dayWise => 'Day-wise only',
    RoomBookingMode.mixed => 'Mixed beds',
  };
  static RoomBookingMode fromApi(String value) => switch (value) {
    'DAY_WISE' => RoomBookingMode.dayWise,
    'MIXED' => RoomBookingMode.mixed,
    _ => RoomBookingMode.monthly,
  };
}

extension RoomTypeX on RoomType {
  String get apiValue => this == RoomType.ac ? 'AC' : 'NON_AC';
  String get label => this == RoomType.ac ? 'AC' : 'Non-AC';
  static RoomType fromApi(String value) => value == 'AC' ? RoomType.ac : RoomType.nonAc;
}

class Room {
  final String id;
  final String floorId;
  final String roomNumber;
  final int sharingCount;
  final double rentPerBed;
  final RoomType roomType;
  final RoomBookingMode bookingMode;
  final double? dayWiseRate;
  final int noticePeriodDays;
  final double securityDeposit;
  final List<Bed> beds;

  Room({
    required this.id,
    required this.floorId,
    required this.roomNumber,
    required this.sharingCount,
    required this.rentPerBed,
    required this.roomType,
    required this.bookingMode,
    required this.dayWiseRate,
    required this.noticePeriodDays,
    required this.securityDeposit,
    required this.beds,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        floorId: json['floorId'] as String,
        roomNumber: json['roomNumber'] as String,
        sharingCount: json['sharingCount'] as int,
        rentPerBed: (json['rentPerBed'] as num).toDouble(),
        roomType: RoomTypeX.fromApi(json['roomType'] as String),
        bookingMode: RoomBookingModeX.fromApi(json['bookingMode'] as String? ?? 'MONTHLY'),
        dayWiseRate: (json['dayWiseRate'] as num?)?.toDouble(),
        noticePeriodDays: json['noticePeriodDays'] as int? ?? 15,
        securityDeposit: (json['securityDeposit'] as num? ?? 0).toDouble(),
        beds: (json['beds'] as List<dynamic>? ?? []).map((e) => Bed.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
