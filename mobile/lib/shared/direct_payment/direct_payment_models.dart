import '../../student/booking/booking_models.dart';

class DirectPaymentDetails {
  final String bookingId;
  final String ownerName;
  final String upiId;
  final String maskedMobile;
  final double amount;
  final String currency;
  final String upiUri;
  final DateTime? paymentHoldExpiresAt;

  const DirectPaymentDetails({
    required this.bookingId,
    required this.ownerName,
    required this.upiId,
    required this.maskedMobile,
    required this.amount,
    required this.currency,
    required this.upiUri,
    required this.paymentHoldExpiresAt,
  });

  factory DirectPaymentDetails.fromJson(Map<String, dynamic> json) =>
      DirectPaymentDetails(
        bookingId: json['bookingId'] as String,
        ownerName: json['ownerName'] as String,
        upiId: json['upiId'] as String,
        maskedMobile: json['maskedMobile'] as String? ?? '',
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'INR',
        upiUri: json['upiUri'] as String? ?? '',
        paymentHoldExpiresAt: json['paymentHoldExpiresAt'] == null
            ? null
            : DateTime.tryParse(json['paymentHoldExpiresAt'] as String),
      );
}

enum DirectPaymentRequestStatus {
  pending,
  approved,
  rejected,
  reviewOverdue,
  cancelled,
  expired,
  unknown,
}

extension DirectPaymentRequestStatusX on DirectPaymentRequestStatus {
  static DirectPaymentRequestStatus fromApi(String value) => switch (value) {
        'PENDING' => DirectPaymentRequestStatus.pending,
        'APPROVED' => DirectPaymentRequestStatus.approved,
        'REJECTED' => DirectPaymentRequestStatus.rejected,
        'REVIEW_OVERDUE' => DirectPaymentRequestStatus.reviewOverdue,
        'CANCELLED' => DirectPaymentRequestStatus.cancelled,
        'EXPIRED' => DirectPaymentRequestStatus.expired,
        _ => DirectPaymentRequestStatus.unknown,
      };

  String get apiValue => switch (this) {
        DirectPaymentRequestStatus.pending => 'PENDING',
        DirectPaymentRequestStatus.approved => 'APPROVED',
        DirectPaymentRequestStatus.rejected => 'REJECTED',
        DirectPaymentRequestStatus.reviewOverdue => 'REVIEW_OVERDUE',
        DirectPaymentRequestStatus.cancelled => 'CANCELLED',
        DirectPaymentRequestStatus.expired => 'EXPIRED',
        DirectPaymentRequestStatus.unknown => 'UNKNOWN',
      };

  String get label => switch (this) {
        DirectPaymentRequestStatus.pending => 'Awaiting owner verification',
        DirectPaymentRequestStatus.approved => 'Approved',
        DirectPaymentRequestStatus.rejected => 'Rejected',
        DirectPaymentRequestStatus.reviewOverdue => 'Review overdue',
        DirectPaymentRequestStatus.cancelled => 'Cancelled',
        DirectPaymentRequestStatus.expired => 'Expired',
        DirectPaymentRequestStatus.unknown => 'Status unavailable',
      };
}

class DirectPaymentRequest {
  final String id;
  final String bookingId;
  final String pgId;
  final String pgName;
  final String customerName;
  final String maskedCustomerPhone;
  final String bedId;
  final String bedLabel;
  final String roomNumber;
  final BookingType bookingType;
  final DateTime checkInDate;
  final DateTime? checkOutDate;
  final double quotedAmount;
  final String currency;
  final String transactionReference;
  final DirectPaymentRequestStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewDueAt;
  final double? confirmedAmount;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  const DirectPaymentRequest({
    required this.id,
    required this.bookingId,
    required this.pgId,
    required this.pgName,
    required this.customerName,
    required this.maskedCustomerPhone,
    required this.bedId,
    required this.bedLabel,
    required this.roomNumber,
    required this.bookingType,
    required this.checkInDate,
    required this.checkOutDate,
    required this.quotedAmount,
    required this.currency,
    required this.transactionReference,
    required this.status,
    required this.submittedAt,
    required this.reviewDueAt,
    required this.confirmedAmount,
    required this.reviewedAt,
    required this.rejectionReason,
  });

  factory DirectPaymentRequest.fromJson(Map<String, dynamic> json) =>
      DirectPaymentRequest(
        id: json['id'] as String,
        bookingId: json['bookingId'] as String,
        pgId: json['pgId'] as String,
        pgName: json['pgName'] as String? ?? 'PG',
        customerName: json['customerName'] as String? ?? 'Customer',
        maskedCustomerPhone: json['maskedCustomerPhone'] as String? ?? '',
        bedId: json['bedId'] as String? ?? '',
        bedLabel: json['bedLabel'] as String? ?? 'Bed',
        roomNumber: json['roomNumber'] as String? ?? '',
        bookingType:
            BookingTypeX.fromApi(json['bookingType'] as String? ?? 'MONTHLY'),
        checkInDate: DateTime.parse(json['checkInDate'] as String),
        checkOutDate: json['checkOutDate'] == null
            ? null
            : DateTime.tryParse(json['checkOutDate'] as String),
        quotedAmount: (json['quotedAmount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'INR',
        transactionReference:
            (json['transactionReference'] ?? json['customerUtr']) as String? ??
                '',
        status: DirectPaymentRequestStatusX.fromApi(
            json['status'] as String? ?? 'UNKNOWN'),
        submittedAt: json['submittedAt'] == null
            ? null
            : DateTime.tryParse(json['submittedAt'] as String),
        reviewDueAt: json['reviewDueAt'] == null
            ? null
            : DateTime.tryParse(json['reviewDueAt'] as String),
        confirmedAmount: (json['confirmedAmount'] as num?)?.toDouble(),
        reviewedAt: json['reviewedAt'] == null
            ? null
            : DateTime.tryParse(json['reviewedAt'] as String),
        rejectionReason: json['rejectionReason'] as String?,
      );
}

class DirectPaymentSettings {
  final String pgId;
  final bool enabled;
  final String beneficiaryName;
  final String upiId;
  final String mobileNumber;
  final bool verified;
  final DateTime? verifiedAt;

  const DirectPaymentSettings({
    required this.pgId,
    required this.enabled,
    required this.beneficiaryName,
    required this.upiId,
    required this.mobileNumber,
    required this.verified,
    required this.verifiedAt,
  });

  factory DirectPaymentSettings.fromJson(Map<String, dynamic> json) =>
      DirectPaymentSettings(
        pgId: json['pgId'] as String,
        enabled: json['enabled'] as bool? ?? false,
        beneficiaryName: json['beneficiaryName'] as String? ?? '',
        upiId: json['upiId'] as String? ?? '',
        mobileNumber: json['mobileNumber'] as String? ?? '',
        verified: json['verified'] as bool? ?? false,
        verifiedAt: json['verifiedAt'] == null
            ? null
            : DateTime.tryParse(json['verifiedAt'] as String),
      );
}
