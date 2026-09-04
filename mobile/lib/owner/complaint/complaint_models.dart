enum ComplaintCategory { maintenance, cleanliness, noise, security, billing, other }

extension ComplaintCategoryX on ComplaintCategory {
  String get apiValue => switch (this) {
        ComplaintCategory.maintenance => 'MAINTENANCE',
        ComplaintCategory.cleanliness => 'CLEANLINESS',
        ComplaintCategory.noise => 'NOISE',
        ComplaintCategory.security => 'SECURITY',
        ComplaintCategory.billing => 'BILLING',
        ComplaintCategory.other => 'OTHER',
      };

  String get label => switch (this) {
        ComplaintCategory.maintenance => 'Maintenance',
        ComplaintCategory.cleanliness => 'Cleanliness',
        ComplaintCategory.noise => 'Noise',
        ComplaintCategory.security => 'Security',
        ComplaintCategory.billing => 'Billing',
        ComplaintCategory.other => 'Other',
      };

  static ComplaintCategory fromApi(String value) =>
      ComplaintCategory.values.firstWhere((c) => c.apiValue == value, orElse: () => ComplaintCategory.other);
}

enum ComplaintPriority { low, medium, high }

extension ComplaintPriorityX on ComplaintPriority {
  String get apiValue => switch (this) {
        ComplaintPriority.low => 'LOW',
        ComplaintPriority.medium => 'MEDIUM',
        ComplaintPriority.high => 'HIGH',
      };

  String get label => switch (this) {
        ComplaintPriority.low => 'Low',
        ComplaintPriority.medium => 'Medium',
        ComplaintPriority.high => 'High',
      };

  static ComplaintPriority fromApi(String value) =>
      ComplaintPriority.values.firstWhere((p) => p.apiValue == value, orElse: () => ComplaintPriority.medium);
}

enum ComplaintStatus { open, inProgress, resolved, closed }

extension ComplaintStatusX on ComplaintStatus {
  String get apiValue => switch (this) {
        ComplaintStatus.open => 'OPEN',
        ComplaintStatus.inProgress => 'IN_PROGRESS',
        ComplaintStatus.resolved => 'RESOLVED',
        ComplaintStatus.closed => 'CLOSED',
      };

  String get label => switch (this) {
        ComplaintStatus.open => 'Open',
        ComplaintStatus.inProgress => 'In progress',
        ComplaintStatus.resolved => 'Resolved',
        ComplaintStatus.closed => 'Closed',
      };

  static ComplaintStatus fromApi(String value) =>
      ComplaintStatus.values.firstWhere((s) => s.apiValue == value, orElse: () => ComplaintStatus.open);
}

class Complaint {
  final String id;
  final String studentId;
  final String studentName;
  final ComplaintCategory category;
  final ComplaintPriority priority;
  final String description;
  final ComplaintStatus status;
  final String? resolutionNotes;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  Complaint({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.category,
    required this.priority,
    required this.description,
    required this.status,
    this.resolutionNotes,
    this.resolvedAt,
    required this.createdAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
        id: json['id'] as String,
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String,
        category: ComplaintCategoryX.fromApi(json['category'] as String),
        priority: ComplaintPriorityX.fromApi(json['priority'] as String),
        description: json['description'] as String,
        status: ComplaintStatusX.fromApi(json['status'] as String),
        resolutionNotes: json['resolutionNotes'] as String?,
        resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt'] as String) : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
