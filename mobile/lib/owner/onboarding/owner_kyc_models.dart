enum OwnerKycStatus {
  draft('DRAFT'),
  submitted('SUBMITTED'),
  verified('VERIFIED'),
  rejected('REJECTED');

  const OwnerKycStatus(this.apiValue);
  final String apiValue;

  static OwnerKycStatus fromJson(String value) => values.firstWhere(
        (status) => status.apiValue == value,
        orElse: () => OwnerKycStatus.draft,
      );
}

enum OwnerKycDocumentType {
  panCard('PAN_CARD', 'PAN card'),
  aadhaarFront('AADHAAR_FRONT', 'Aadhaar front'),
  aadhaarBack('AADHAAR_BACK', 'Aadhaar back'),
  ownerPhoto('OWNER_PHOTO', 'Owner photo'),
  pgPhoto('PG_PHOTO', 'PG photo');

  const OwnerKycDocumentType(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static OwnerKycDocumentType fromJson(String value) => values.firstWhere(
        (type) => type.apiValue == value,
      );
}

class OwnerKycDocument {
  final String id;
  final OwnerKycDocumentType type;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  const OwnerKycDocument({
    required this.id,
    required this.type,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  factory OwnerKycDocument.fromJson(Map<String, dynamic> json) =>
      OwnerKycDocument(
        id: json['id'] as String,
        type: OwnerKycDocumentType.fromJson(json['type'] as String),
        fileName: json['fileName'] as String,
        contentType: json['contentType'] as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
      );
}

class OwnerKycSubmission {
  final String id;
  final String pgId;
  final String pgName;
  final String ownerName;
  final String? verifiedPhone;
  final String legalName;
  final String panLastFour;
  final String aadhaarLastFour;
  final OwnerKycStatus status;
  final String? reviewNote;
  final DateTime? submittedAt;
  final List<OwnerKycDocument> documents;

  const OwnerKycSubmission({
    required this.id,
    required this.pgId,
    required this.pgName,
    required this.ownerName,
    required this.verifiedPhone,
    required this.legalName,
    required this.panLastFour,
    required this.aadhaarLastFour,
    required this.status,
    required this.reviewNote,
    required this.submittedAt,
    required this.documents,
  });

  bool hasDocument(OwnerKycDocumentType type) =>
      documents.any((document) => document.type == type);

  bool get hasAllDocuments => OwnerKycDocumentType.values.every(hasDocument);

  factory OwnerKycSubmission.fromJson(Map<String, dynamic> json) =>
      OwnerKycSubmission(
        id: json['id'] as String,
        pgId: json['pgId'] as String,
        pgName: json['pgName'] as String,
        ownerName: json['ownerName'] as String,
        verifiedPhone: json['verifiedPhone'] as String?,
        legalName: json['legalName'] as String,
        panLastFour: json['panLastFour'] as String,
        aadhaarLastFour: json['aadhaarLastFour'] as String,
        status: OwnerKycStatus.fromJson(json['status'] as String),
        reviewNote: json['reviewNote'] as String?,
        submittedAt: json['submittedAt'] == null
            ? null
            : DateTime.parse(json['submittedAt'] as String),
        documents: (json['documents'] as List<dynamic>? ?? const [])
            .map((item) =>
                OwnerKycDocument.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
