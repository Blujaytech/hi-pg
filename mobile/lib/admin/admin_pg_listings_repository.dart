import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../shared/api_client.dart';

class AdminPgListing {
  final String id;
  final String name;
  final String address;
  final String city;
  final String? state;
  final String? pincode;
  final double? latitude;
  final double? longitude;
  final String? locationUrl;
  final String? description;
  final String? photoUrl;
  final String genderPreference;
  final String claimStatus;
  final String verificationStatus;
  final bool bookingEnabled;
  final String? ownerName;
  final String? ownerMobile;
  final String invitationStatus;
  final String? invitationDeliveryStatus;
  final String? invitationFailureReason;
  final int interestCount;

  const AdminPgListing({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    required this.locationUrl,
    required this.description,
    required this.photoUrl,
    required this.genderPreference,
    required this.claimStatus,
    required this.verificationStatus,
    required this.bookingEnabled,
    required this.ownerName,
    required this.ownerMobile,
    required this.invitationStatus,
    required this.invitationDeliveryStatus,
    required this.invitationFailureReason,
    required this.interestCount,
  });

  factory AdminPgListing.fromJson(Map<String, dynamic> json) => AdminPgListing(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        city: json['city'] as String,
        state: json['state'] as String?,
        pincode: json['pincode'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        locationUrl: json['locationUrl'] as String?,
        description: json['description'] as String?,
        photoUrl: json['photoUrl'] as String?,
        genderPreference: json['genderPreference'] as String,
        claimStatus: json['claimStatus'] as String,
        verificationStatus: json['verificationStatus'] as String,
        bookingEnabled: json['bookingEnabled'] as bool? ?? false,
        ownerName: json['ownerName'] as String?,
        ownerMobile: json['ownerMobile'] as String?,
        invitationStatus: json['invitationStatus'] as String,
        invitationDeliveryStatus: json['invitationDeliveryStatus'] as String?,
        invitationFailureReason: json['invitationFailureReason'] as String?,
        interestCount: json['interestCount'] as int? ?? 0,
      );
}

class PgImportRow {
  final String id;
  final int sourceRowNumber;
  final String? name;
  final String? ownerMobile;
  final String? address;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? locationUrl;
  final int imageCount;
  final String validationStatus;
  final List<String> validationMessages;
  final String publishStatus;
  final String invitationStatus;

  const PgImportRow({
    required this.id,
    required this.sourceRowNumber,
    required this.name,
    required this.ownerMobile,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.locationUrl,
    required this.imageCount,
    required this.validationStatus,
    required this.validationMessages,
    required this.publishStatus,
    required this.invitationStatus,
  });

  factory PgImportRow.fromJson(Map<String, dynamic> json) => PgImportRow(
        id: json['id'] as String,
        sourceRowNumber: json['sourceRowNumber'] as int,
        name: json['name'] as String?,
        ownerMobile: json['ownerMobile'] as String?,
        address: json['address'] as String?,
        city: json['city'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        locationUrl: json['locationUrl'] as String?,
        imageCount: json['imageCount'] as int? ?? 0,
        validationStatus: json['validationStatus'] as String,
        validationMessages: (json['validationMessages'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
        publishStatus: json['publishStatus'] as String,
        invitationStatus: json['invitationStatus'] as String,
      );
}

class PgImportBatch {
  final String id;
  final String fileName;
  final String sourceSheet;
  final String status;
  final int totalRows;
  final int publishableRows;
  final int warningRows;
  final int invalidRows;
  final int duplicateRows;
  final int validMobileRows;
  final int publishedRows;
  final int invitedRows;
  final int skippedRows;
  final List<PgImportRow> rows;

  const PgImportBatch({
    required this.id,
    required this.fileName,
    required this.sourceSheet,
    required this.status,
    required this.totalRows,
    required this.publishableRows,
    required this.warningRows,
    required this.invalidRows,
    required this.duplicateRows,
    required this.validMobileRows,
    required this.publishedRows,
    required this.invitedRows,
    required this.skippedRows,
    required this.rows,
  });

  factory PgImportBatch.fromJson(Map<String, dynamic> json) => PgImportBatch(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        sourceSheet: json['sourceSheet'] as String,
        status: json['status'] as String,
        totalRows: json['totalRows'] as int? ?? 0,
        publishableRows: json['publishableRows'] as int? ?? 0,
        warningRows: json['warningRows'] as int? ?? 0,
        invalidRows: json['invalidRows'] as int? ?? 0,
        duplicateRows: json['duplicateRows'] as int? ?? 0,
        validMobileRows: json['validMobileRows'] as int? ?? 0,
        publishedRows: json['publishedRows'] as int? ?? 0,
        invitedRows: json['invitedRows'] as int? ?? 0,
        skippedRows: json['skippedRows'] as int? ?? 0,
        rows: (json['rows'] as List<dynamic>? ?? [])
            .map((row) => PgImportRow.fromJson(row as Map<String, dynamic>))
            .toList(),
      );
}

class AdminPgListingsRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<AdminPgListing>> list() async {
    final response = await _client.get<List<dynamic>>('/admin/pg-listings');
    return response.data!
        .map((item) => AdminPgListing.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminPgListing> create(Map<String, dynamic> data) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/pg-listings',
      data: data,
    );
    return AdminPgListing.fromJson(response.data!);
  }

  Future<AdminPgListing> update(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/admin/pg-listings/$id',
      data: data,
    );
    return AdminPgListing.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await _client.delete<void>('/admin/pg-listings/$id');
  }

  Future<AdminPgListing> retryInvitation(String id) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/pg-listings/$id/invitation',
    );
    return AdminPgListing.fromJson(response.data!);
  }

  Future<List<PgImportBatch>> listImports() async {
    final response = await _client.get<List<dynamic>>('/admin/pg-imports');
    return response.data!
        .map((item) => PgImportBatch.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PgImportBatch> getImport(String id) async {
    final response =
        await _client.get<Map<String, dynamic>>('/admin/pg-imports/$id');
    return PgImportBatch.fromJson(response.data!);
  }

  Future<PgImportBatch> uploadImport(String fileName, Uint8List bytes) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/pg-imports',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      }),
    );
    return PgImportBatch.fromJson(response.data!);
  }

  Future<PgImportBatch> publishImport(String id) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/pg-imports/$id/publish-and-invite',
    );
    return PgImportBatch.fromJson(response.data!);
  }

  Future<PgImportBatch> updateImportLocation(
    String batchId,
    String rowId, {
    double? latitude,
    double? longitude,
    String? locationUrl,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/pg-imports/$batchId/rows/$rowId/location',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'locationUrl': locationUrl,
      },
    );
    return PgImportBatch.fromJson(response.data!);
  }
}
