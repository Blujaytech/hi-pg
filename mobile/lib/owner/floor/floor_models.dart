class Floor {
  final String id;
  final String pgId;
  final String name;
  final int floorNumber;

  Floor({required this.id, required this.pgId, required this.name, required this.floorNumber});

  factory Floor.fromJson(Map<String, dynamic> json) => Floor(
        id: json['id'] as String,
        pgId: json['pgId'] as String,
        name: json['name'] as String,
        floorNumber: json['floorNumber'] as int,
      );
}
