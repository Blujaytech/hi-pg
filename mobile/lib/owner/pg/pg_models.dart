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
        GenderPreference.coEd => 'Co-ed',
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
  static PgStatus fromApi(String value) => value == 'ACTIVE' ? PgStatus.active : PgStatus.inactive;
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
  final GenderPreference genderPreference;
  final PgStatus status;

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
    required this.genderPreference,
    required this.status,
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
        genderPreference: GenderPreferenceX.fromApi(json['genderPreference'] as String),
        status: PgStatusX.fromApi(json['status'] as String),
      );
}
