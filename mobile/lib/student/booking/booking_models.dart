enum BookingStatus { confirmed, cancelled }

extension BookingStatusX on BookingStatus {
  static BookingStatus fromApi(String value) => value == 'CANCELLED' ? BookingStatus.cancelled : BookingStatus.confirmed;

  String get label => this == BookingStatus.confirmed ? 'Confirmed' : 'Cancelled';
}

class Booking {
  final String id;
  final String studentId;
  final String pgId;
  final String pgName;
  final String bedId;
  final String bedLabel;
  final String roomNumber;
  final BookingStatus status;
  final DateTime moveInDate;
  final DateTime confirmedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  Booking({
    required this.id,
    required this.studentId,
    required this.pgId,
    required this.pgName,
    required this.bedId,
    required this.bedLabel,
    required this.roomNumber,
    required this.status,
    required this.moveInDate,
    required this.confirmedAt,
    required this.cancelledAt,
    required this.cancellationReason,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        studentId: json['studentId'] as String,
        pgId: json['pgId'] as String,
        pgName: json['pgName'] as String,
        bedId: json['bedId'] as String,
        bedLabel: json['bedLabel'] as String,
        roomNumber: json['roomNumber'] as String,
        status: BookingStatusX.fromApi(json['status'] as String),
        moveInDate: DateTime.parse(json['moveInDate'] as String),
        confirmedAt: DateTime.parse(json['confirmedAt'] as String),
        cancelledAt: json['cancelledAt'] != null ? DateTime.parse(json['cancelledAt'] as String) : null,
        cancellationReason: json['cancellationReason'] as String?,
      );
}
