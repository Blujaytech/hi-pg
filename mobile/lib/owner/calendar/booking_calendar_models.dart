class BookingCalendarEntry {
  final String bookingId;
  final String bedId;
  final String bedLabel;
  final String customerName;
  final String bookingType;
  final String status;
  final DateTime startDate;
  final DateTime? endDate;
  final String? checkOutTime;
  final DateTime? paymentExpiresAt;

  BookingCalendarEntry(
      {required this.bookingId,
      required this.bedId,
      required this.bedLabel,
      required this.customerName,
      required this.bookingType,
      required this.status,
      required this.startDate,
      required this.endDate,
      required this.checkOutTime,
      required this.paymentExpiresAt});

  factory BookingCalendarEntry.fromJson(Map<String, dynamic> json) =>
      BookingCalendarEntry(
        bookingId: json['bookingId'] as String,
        bedId: json['bedId'] as String,
        bedLabel: json['bedLabel'] as String,
        customerName: json['customerName'] as String,
        bookingType: json['bookingType'] as String,
        status: json['status'] as String,
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] == null
            ? null
            : DateTime.parse(json['endDate'] as String),
        checkOutTime: json['checkOutTime'] as String?,
        paymentExpiresAt: json['paymentExpiresAt'] == null
            ? null
            : DateTime.parse(json['paymentExpiresAt'] as String),
      );
}
