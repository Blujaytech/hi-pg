import 'package:flutter/material.dart';

import '../app_states.dart';

enum SupportCategory {
  account,
  booking,
  payment,
  kycDocuments,
  technical,
  other
}

extension SupportCategoryX on SupportCategory {
  String get apiValue => switch (this) {
        SupportCategory.account => 'ACCOUNT',
        SupportCategory.booking => 'BOOKING',
        SupportCategory.payment => 'PAYMENT',
        SupportCategory.kycDocuments => 'KYC_DOCUMENTS',
        SupportCategory.technical => 'TECHNICAL',
        SupportCategory.other => 'OTHER',
      };

  String get label => switch (this) {
        SupportCategory.account => 'Account & login',
        SupportCategory.booking => 'Booking assistance',
        SupportCategory.payment => 'Payment assistance',
        SupportCategory.kycDocuments => 'KYC & documents',
        SupportCategory.technical => 'Technical issue',
        SupportCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        SupportCategory.account => Icons.manage_accounts_outlined,
        SupportCategory.booking => Icons.event_available_outlined,
        SupportCategory.payment => Icons.payments_outlined,
        SupportCategory.kycDocuments => Icons.badge_outlined,
        SupportCategory.technical => Icons.build_outlined,
        SupportCategory.other => Icons.help_outline_rounded,
      };

  static SupportCategory fromApi(String value) =>
      SupportCategory.values.firstWhere((item) => item.apiValue == value,
          orElse: () => SupportCategory.other);
}

enum SupportStatus { open, inProgress, resolved }

extension SupportStatusX on SupportStatus {
  String get apiValue => switch (this) {
        SupportStatus.open => 'OPEN',
        SupportStatus.inProgress => 'IN_PROGRESS',
        SupportStatus.resolved => 'RESOLVED',
      };

  String get label => switch (this) {
        SupportStatus.open => 'Open',
        SupportStatus.inProgress => 'In progress',
        SupportStatus.resolved => 'Resolved',
      };

  StatusTone get tone => switch (this) {
        SupportStatus.open => StatusTone.warning,
        SupportStatus.inProgress => StatusTone.dark,
        SupportStatus.resolved => StatusTone.success,
      };

  static SupportStatus fromApi(String value) =>
      SupportStatus.values.firstWhere((item) => item.apiValue == value,
          orElse: () => SupportStatus.open);
}

class SupportTicket {
  final String id;
  final String requesterId;
  final String requesterName;
  final String requesterRole;
  final String? requesterEmail;
  final String? requesterPhone;
  final SupportCategory category;
  final String subject;
  final String description;
  final SupportStatus status;
  final String? adminResponse;
  final String? respondedByName;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupportTicket({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterRole,
    this.requesterEmail,
    this.requesterPhone,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    this.adminResponse,
    this.respondedByName,
    this.respondedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] as String,
        requesterId: json['requesterId'] as String,
        requesterName: json['requesterName'] as String,
        requesterRole: json['requesterRole'] as String,
        requesterEmail: json['requesterEmail'] as String?,
        requesterPhone: json['requesterPhone'] as String?,
        category: SupportCategoryX.fromApi(json['category'] as String),
        subject: json['subject'] as String,
        description: json['description'] as String,
        status: SupportStatusX.fromApi(json['status'] as String),
        adminResponse: json['adminResponse'] as String?,
        respondedByName: json['respondedByName'] as String?,
        respondedAt: json['respondedAt'] == null
            ? null
            : DateTime.parse(json['respondedAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
