import '../shared/api_client.dart';

class AdminPgListing {
  final String id;
  final String name;
  final String address;
  final String city;
  final String? state;
  final String? pincode;
  final double latitude;
  final double longitude;
  final String? description;
  final String genderPreference;
  final String claimStatus;
  final String verificationStatus;
  final bool bookingEnabled;
  final String ownerName;
  final String ownerMobile;
  final String invitationStatus;
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
    required this.description,
    required this.genderPreference,
    required this.claimStatus,
    required this.verificationStatus,
    required this.bookingEnabled,
    required this.ownerName,
    required this.ownerMobile,
    required this.invitationStatus,
    required this.interestCount,
  });

  factory AdminPgListing.fromJson(Map<String, dynamic> json) => AdminPgListing(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        city: json['city'] as String,
        state: json['state'] as String?,
        pincode: json['pincode'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        description: json['description'] as String?,
        genderPreference: json['genderPreference'] as String,
        claimStatus: json['claimStatus'] as String,
        verificationStatus: json['verificationStatus'] as String,
        bookingEnabled: json['bookingEnabled'] as bool? ?? false,
        ownerName: json['ownerName'] as String,
        ownerMobile: json['ownerMobile'] as String,
        invitationStatus: json['invitationStatus'] as String,
        interestCount: json['interestCount'] as int? ?? 0,
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
}
