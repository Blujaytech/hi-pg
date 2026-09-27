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

  static GenderPreference fromApi(String value) =>
      GenderPreference.values.firstWhere(
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
  final String? photoUrl;
  final GenderPreference genderPreference;
  final double? latitude;
  final double? longitude;
  final int availableBeds;
  final double? minRentPerBed;
  final double? maxRentPerBed;

  /// Stay types across the PG's rooms. Null when the server predates these
  /// fields -- treat as unknown, not as "no".
  final bool? offersMonthly;
  final bool? offersDayWise;
  final double? minDayWiseRate;

  PgSearchResult({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    required this.description,
    this.photoUrl,
    required this.genderPreference,
    required this.latitude,
    required this.longitude,
    required this.availableBeds,
    required this.minRentPerBed,
    required this.maxRentPerBed,
    this.offersMonthly,
    this.offersDayWise,
    this.minDayWiseRate,
  });

  factory PgSearchResult.fromJson(Map<String, dynamic> json) => PgSearchResult(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        address: json['address'] as String,
        description: json['description'] as String?,
        photoUrl: json['photoUrl'] as String?,
        genderPreference:
            GenderPreferenceX.fromApi(json['genderPreference'] as String),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        availableBeds: json['availableBeds'] as int,
        minRentPerBed: (json['minRentPerBed'] as num?)?.toDouble(),
        maxRentPerBed: (json['maxRentPerBed'] as num?)?.toDouble(),
        offersMonthly: json['offersMonthly'] as bool?,
        offersDayWise: json['offersDayWise'] as bool?,
        minDayWiseRate: (json['minDayWiseRate'] as num?)?.toDouble(),
      );
}

class PagedResult<T> {
  final List<T> content;
  final int page;
  final int totalPages;
  final int totalElements;

  PagedResult(
      {required this.content,
      required this.page,
      required this.totalPages,
      required this.totalElements});
}

class AvailableBedOption {
  final String id;
  final String label;
  final String bookingMode;

  AvailableBedOption(
      {required this.id, required this.label, required this.bookingMode});

  factory AvailableBedOption.fromJson(Map<String, dynamic> json) =>
      AvailableBedOption(
          id: json['id'] as String,
          label: json['label'] as String,
          bookingMode: json['bookingMode'] as String? ?? 'MONTHLY');
}

/// One bed in a room's bed map. [option] is set when the bed can be booked.
class BedSeat {
  final String label;
  final AvailableBedOption? option;

  const BedSeat({required this.label, this.option});

  bool get available => option != null;
}

class RoomAvailability {
  final String roomId;
  final String roomNumber;
  final String roomType;
  final int sharingCount;
  final double rentPerBed;
  final double? dayWiseRate;
  final String bookingMode;
  final int noticePeriodDays;
  final double securityDeposit;
  final int availableBeds;
  final List<AvailableBedOption> availableBedOptions;

  /// Every bed in the room, free or taken, in bed order.
  final List<BedSeat> beds;

  RoomAvailability({
    required this.roomId,
    required this.roomNumber,
    required this.roomType,
    required this.sharingCount,
    required this.rentPerBed,
    required this.dayWiseRate,
    required this.bookingMode,
    required this.noticePeriodDays,
    required this.securityDeposit,
    required this.availableBeds,
    required this.availableBedOptions,
    List<BedSeat>? beds,
  }) : beds = beds ?? _inferBeds(sharingCount, availableBedOptions);

  /// Servers without the `beds` field only list the free beds. Beds are
  /// created as "Bed 1".."Bed N" (N = sharing count), so the missing labels
  /// are the taken ones.
  static List<BedSeat> _inferBeds(
      int sharingCount, List<AvailableBedOption> options) {
    final byLabel = {for (final option in options) option.label: option};
    final seats = [
      for (var i = 1; i <= sharingCount; i++)
        BedSeat(label: 'Bed $i', option: byLabel.remove('Bed $i')),
    ];
    // Any free bed whose label doesn't follow the pattern still shows.
    seats.addAll(byLabel.values
        .map((option) => BedSeat(label: option.label, option: option)));
    return seats;
  }

  factory RoomAvailability.fromJson(Map<String, dynamic> json) {
    final options = (json['availableBedOptions'] as List<dynamic>? ?? [])
        .map((b) => AvailableBedOption.fromJson(b as Map<String, dynamic>))
        .toList();
    final byId = {for (final option in options) option.id: option};
    final beds = (json['beds'] as List<dynamic>?)?.map((raw) {
      final bed = raw as Map<String, dynamic>;
      final option = byId[bed['id'] as String];
      return BedSeat(
        label: bed['label'] as String,
        option: (bed['available'] as bool? ?? false) ? option : null,
      );
    }).toList()
      ?..sort((a, b) => _bedOrder(a.label).compareTo(_bedOrder(b.label)));
    return RoomAvailability(
        roomId: json['roomId'] as String,
        roomNumber: json['roomNumber'] as String,
        roomType: json['roomType'] as String,
        sharingCount: json['sharingCount'] as int,
        rentPerBed: (json['rentPerBed'] as num).toDouble(),
        dayWiseRate: (json['dayWiseRate'] as num?)?.toDouble(),
        bookingMode: json['bookingMode'] as String? ?? 'MONTHLY',
        noticePeriodDays: json['noticePeriodDays'] as int? ?? 15,
        securityDeposit: (json['securityDeposit'] as num? ?? 0).toDouble(),
        availableBeds: json['availableBeds'] as int,
        availableBedOptions: options,
        beds: beds);
  }

  /// "Bed 10" sorts after "Bed 9", not after "Bed 1".
  static int _bedOrder(String label) =>
      int.tryParse(label.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1 << 20;
}

class FloorAvailability {
  final String floorId;
  final String name;
  final int floorNumber;
  final List<RoomAvailability> rooms;

  FloorAvailability(
      {required this.floorId,
      required this.name,
      required this.floorNumber,
      required this.rooms});

  factory FloorAvailability.fromJson(Map<String, dynamic> json) =>
      FloorAvailability(
        floorId: json['floorId'] as String,
        name: json['name'] as String,
        floorNumber: json['floorNumber'] as int,
        rooms: (json['rooms'] as List<dynamic>)
            .map((r) => RoomAvailability.fromJson(r as Map<String, dynamic>))
            .toList(),
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
  final String? photoUrl;
  final GenderPreference genderPreference;
  final double? latitude;
  final double? longitude;
  final int totalBeds;
  final int availableBeds;
  final bool directPaymentAvailable;
  final List<FloorAvailability> floors;

  PgDetails({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.description,
    this.photoUrl,
    required this.genderPreference,
    required this.latitude,
    required this.longitude,
    required this.totalBeds,
    required this.availableBeds,
    required this.directPaymentAvailable,
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
        photoUrl: json['photoUrl'] as String?,
        genderPreference:
            GenderPreferenceX.fromApi(json['genderPreference'] as String),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        totalBeds: json['totalBeds'] as int,
        availableBeds: json['availableBeds'] as int,
        directPaymentAvailable:
            json['directPaymentAvailable'] as bool? ?? false,
        floors: (json['floors'] as List<dynamic>)
            .map((f) => FloorAvailability.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
}
