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

  static GenderPreference fromApi(String value) => GenderPreference.values.firstWhere(
        (g) => g.apiValue == value,
        orElse: () => GenderPreference.coEd,
      );
}

class PgSearchResult {
  final String id;
  final String name;
  final String city;
  final String address;
  final String? description;
  final GenderPreference genderPreference;
  final double? latitude;
  final double? longitude;
  final int availableBeds;
  final double? minRentPerBed;
  final double? maxRentPerBed;

  PgSearchResult({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    required this.description,
    required this.genderPreference,
    required this.latitude,
    required this.longitude,
    required this.availableBeds,
    required this.minRentPerBed,
    required this.maxRentPerBed,
  });

  factory PgSearchResult.fromJson(Map<String, dynamic> json) => PgSearchResult(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        address: json['address'] as String,
        description: json['description'] as String?,
        genderPreference: GenderPreferenceX.fromApi(json['genderPreference'] as String),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        availableBeds: json['availableBeds'] as int,
        minRentPerBed: (json['minRentPerBed'] as num?)?.toDouble(),
        maxRentPerBed: (json['maxRentPerBed'] as num?)?.toDouble(),
      );
}

class PagedResult<T> {
  final List<T> content;
  final int page;
  final int totalPages;
  final int totalElements;

  PagedResult({required this.content, required this.page, required this.totalPages, required this.totalElements});
}

class AvailableBedOption {
  final String id;
  final String label;

  AvailableBedOption({required this.id, required this.label});

  factory AvailableBedOption.fromJson(Map<String, dynamic> json) =>
      AvailableBedOption(id: json['id'] as String, label: json['label'] as String);
}

class RoomAvailability {
  final String roomId;
  final String roomNumber;
  final String roomType;
  final int sharingCount;
  final double rentPerBed;
  final int availableBeds;
  final List<AvailableBedOption> availableBedOptions;

  RoomAvailability({
    required this.roomId,
    required this.roomNumber,
    required this.roomType,
    required this.sharingCount,
    required this.rentPerBed,
    required this.availableBeds,
    required this.availableBedOptions,
  });

  factory RoomAvailability.fromJson(Map<String, dynamic> json) => RoomAvailability(
        roomId: json['roomId'] as String,
        roomNumber: json['roomNumber'] as String,
        roomType: json['roomType'] as String,
        sharingCount: json['sharingCount'] as int,
        rentPerBed: (json['rentPerBed'] as num).toDouble(),
        availableBeds: json['availableBeds'] as int,
        availableBedOptions: (json['availableBedOptions'] as List<dynamic>? ?? [])
            .map((b) => AvailableBedOption.fromJson(b as Map<String, dynamic>))
            .toList(),
      );
}

class FloorAvailability {
  final String floorId;
  final String name;
  final int floorNumber;
  final List<RoomAvailability> rooms;

  FloorAvailability({required this.floorId, required this.name, required this.floorNumber, required this.rooms});

  factory FloorAvailability.fromJson(Map<String, dynamic> json) => FloorAvailability(
        floorId: json['floorId'] as String,
        name: json['name'] as String,
        floorNumber: json['floorNumber'] as int,
        rooms: (json['rooms'] as List<dynamic>).map((r) => RoomAvailability.fromJson(r as Map<String, dynamic>)).toList(),
      );
}

class PgDetails {
  final String id;
  final String name;
  final String address;
  final String city;
  final String? state;
  final String? pincode;
  final String? description;
  final GenderPreference genderPreference;
  final double? latitude;
  final double? longitude;
  final int totalBeds;
  final int availableBeds;
  final List<FloorAvailability> floors;

  PgDetails({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.description,
    required this.genderPreference,
    required this.latitude,
    required this.longitude,
    required this.totalBeds,
    required this.availableBeds,
    required this.floors,
  });

  factory PgDetails.fromJson(Map<String, dynamic> json) => PgDetails(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        city: json['city'] as String,
        state: json['state'] as String?,
        pincode: json['pincode'] as String?,
        description: json['description'] as String?,
        genderPreference: GenderPreferenceX.fromApi(json['genderPreference'] as String),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        totalBeds: json['totalBeds'] as int,
        availableBeds: json['availableBeds'] as int,
        floors: (json['floors'] as List<dynamic>).map((f) => FloorAvailability.fromJson(f as Map<String, dynamic>)).toList(),
      );
}
