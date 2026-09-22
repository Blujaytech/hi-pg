enum BookingStatus {
  paymentPending,
  directPaymentReview,
  confirmed,
  checkedIn,
  completed,
  cancelled,
  expired,
  unknown,
}

extension BookingStatusX on BookingStatus {
  static BookingStatus fromApi(String value) => switch (value) {
        'PAYMENT_PENDING' => BookingStatus.paymentPending,
        'DIRECT_PAYMENT_REVIEW' => BookingStatus.directPaymentReview,
        'CONFIRMED' => BookingStatus.confirmed,
        'CHECKED_IN' => BookingStatus.checkedIn,
        'COMPLETED' => BookingStatus.completed,
        'CANCELLED' => BookingStatus.cancelled,
        'EXPIRED' => BookingStatus.expired,
        _ => BookingStatus.unknown,
      };

  String get label => switch (this) {
        BookingStatus.paymentPending => 'Awaiting payment',
        BookingStatus.directPaymentReview => 'Awaiting owner verification',
        BookingStatus.confirmed => 'Confirmed',
        BookingStatus.checkedIn => 'Checked in',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.expired => 'Expired',
        BookingStatus.unknown => 'Status unavailable',
      };
}

enum BookingPaymentChannel { unselected, razorpay, directUpi, unknown }

extension BookingPaymentChannelX on BookingPaymentChannel {
  static BookingPaymentChannel fromApi(String? value) => switch (value) {
        null || 'UNSELECTED' => BookingPaymentChannel.unselected,
        'RAZORPAY' => BookingPaymentChannel.razorpay,
        'DIRECT_UPI' => BookingPaymentChannel.directUpi,
        _ => BookingPaymentChannel.unknown,
      };
}

enum BookingType { monthly, dayWise }

extension BookingTypeX on BookingType {
  String get apiValue => this == BookingType.monthly ? 'MONTHLY' : 'DAY_WISE';
  String get label => this == BookingType.monthly ? 'Monthly' : 'Day-wise';
  static BookingType fromApi(String value) =>
      value == 'DAY_WISE' ? BookingType.dayWise : BookingType.monthly;
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
  final BookingType bookingType;
  final BookingPaymentChannel paymentChannel;
  final DateTime moveInDate;
  final DateTime? checkOutDate;
  final double rentAmount;
  final double securityDepositAmount;
  final double totalAmount;
  final DateTime? paymentExpiresAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime? plannedMoveOutDate;
  final int noticeShortfallDays;

  Booking({
    required this.id,
    required this.studentId,
    required this.pgId,
    required this.pgName,
    required this.bedId,
    required this.bedLabel,
    required this.roomNumber,
    required this.status,
    required this.bookingType,
    required this.paymentChannel,
    required this.moveInDate,
    required this.checkOutDate,
    required this.rentAmount,
    required this.securityDepositAmount,
    required this.totalAmount,
    required this.paymentExpiresAt,
    required this.confirmedAt,
    required this.cancelledAt,
    required this.cancellationReason,
    required this.plannedMoveOutDate,
    required this.noticeShortfallDays,
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
        bookingType:
            BookingTypeX.fromApi(json['bookingType'] as String? ?? 'MONTHLY'),
        paymentChannel:
            BookingPaymentChannelX.fromApi(json['paymentChannel'] as String?),
        moveInDate: DateTime.parse(
            (json['checkInDate'] ?? json['moveInDate']) as String),
        checkOutDate: json['checkOutDate'] == null
            ? null
            : DateTime.parse(json['checkOutDate'] as String),
        rentAmount: (json['rentAmount'] as num? ?? 0).toDouble(),
        securityDepositAmount:
            (json['securityDepositAmount'] as num? ?? 0).toDouble(),
        totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
        paymentExpiresAt: json['paymentExpiresAt'] == null
            ? null
            : DateTime.parse(json['paymentExpiresAt'] as String),
        confirmedAt: json['confirmedAt'] == null
            ? null
            : DateTime.parse(json['confirmedAt'] as String),
        cancelledAt: json['cancelledAt'] == null
            ? null
            : DateTime.parse(json['cancelledAt'] as String),
        cancellationReason: json['cancellationReason'] as String?,
        plannedMoveOutDate: json['plannedMoveOutDate'] == null
            ? null
            : DateTime.parse(json['plannedMoveOutDate'] as String),
        noticeShortfallDays: json['noticeShortfallDays'] as int? ?? 0,
      );
}
