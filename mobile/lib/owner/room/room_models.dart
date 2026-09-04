import '../bed/bed_models.dart';

enum RoomType { nonAc, ac }

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
  final List<Bed> beds;

  Room({
    required this.id,
    required this.floorId,
    required this.roomNumber,
    required this.sharingCount,
    required this.rentPerBed,
    required this.roomType,
    required this.beds,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        floorId: json['floorId'] as String,
        roomNumber: json['roomNumber'] as String,
        sharingCount: json['sharingCount'] as int,
        rentPerBed: (json['rentPerBed'] as num).toDouble(),
        roomType: RoomTypeX.fromApi(json['roomType'] as String),
        beds: (json['beds'] as List<dynamic>? ?? []).map((e) => Bed.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
