enum GenderPreference { male, female, coEd }

extension GenderPreferenceX on GenderPreference {
  String get apiValue => switch (this) {
        GenderPreference.male => 'MALE',
        GenderPreference.female => 'FEMALE',
        GenderPreference.coEd => 'CO_ED',
      };

  String get label => switch (this) {
        GenderPreference.male => 'Male',
        GenderPreference.female => 'Female',
        GenderPreference.coEd => 'Co-Living',
      };

  static GenderPreference fromApi(String value) => switch (value) {
        'MALE' => GenderPreference.male,
        'FEMALE' => GenderPreference.female,
        _ => GenderPreference.coEd,
      };
}

enum PgStatus { active, inactive }

extension PgStatusX on PgStatus {
  String get apiValue => this == PgStatus.active ? 'ACTIVE' : 'INACTIVE';
  static PgStatus fromApi(String value) =>
      value == 'ACTIVE' ? PgStatus.active : PgStatus.inactive;
}

class Pg {
  final String id;
  final String name;
  final String address;
  final String city;
  final String? state;
  final String? pincode;
  final double? latitude;
  final double? longitude;
  final String? description;
  final String? photoUrl;
  final List<PgPhoto> photos;
  final int interestCount;
  final GenderPreference genderPreference;
  final PgStatus status;
  final String claimStatus;
  final String verificationStatus;
  final bool bookingEnabled;
  final bool adminCreated;

  Pg({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    this.state,
    this.pincode,
    this.latitude,
    this.longitude,
    this.description,
    this.photoUrl,
    this.photos = const [],
    this.interestCount = 0,
    required this.genderPreference,
    required this.status,
    this.claimStatus = 'CLAIMED',
    this.verificationStatus = 'UNVERIFIED',
    this.bookingEnabled = false,
    this.adminCreated = false,
  });

  factory Pg.fromJson(Map<String, dynamic> json) => Pg(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        city: json['city'] as String,
        state: json['state'] as String?,
        pincode: json['pincode'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        description: json['description'] as String?,
        photoUrl: json['photoUrl'] as String?,
        photos: (json['photos'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PgPhoto.fromJson)
            .toList(),
        interestCount: (json['interestCount'] as num?)?.toInt() ?? 0,
        genderPreference:
            GenderPreferenceX.fromApi(json['genderPreference'] as String),
        status: PgStatusX.fromApi(json['status'] as String),
        claimStatus: json['claimStatus'] as String? ?? 'CLAIMED',
        verificationStatus:
            json['verificationStatus'] as String? ?? 'UNVERIFIED',
        bookingEnabled: json['bookingEnabled'] as bool? ?? false,
        adminCreated: json['adminCreated'] as bool? ?? false,
      );
}

class PgPhoto {
  final String id;
  final String url;
  final bool cover;
  final int displayOrder;

  const PgPhoto({
    required this.id,
    required this.url,
    required this.cover,
    required this.displayOrder,
  });

  factory PgPhoto.fromJson(Map<String, dynamic> json) => PgPhoto(
        id: json['id'] as String,
        url: json['url'] as String,
        cover: json['cover'] as bool? ?? false,
        displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      );
}
