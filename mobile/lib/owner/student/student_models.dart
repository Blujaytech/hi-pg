enum StudentStatus { active, movedOut }

extension StudentStatusX on StudentStatus {
  String get label => this == StudentStatus.active ? 'Active' : 'Moved out';
  static StudentStatus fromApi(String value) => value == 'MOVED_OUT' ? StudentStatus.movedOut : StudentStatus.active;
}

class Student {
  final String id;
  final String pgId;
  final String? bedId;
  final String? bedLabel;
  final String fullName;
  final String phone;
  final String? email;
  final String? guardianName;
  final String? guardianPhone;
  final String? permanentAddress;
  final String? idProofNumber;
  final DateTime dateOfJoining;
  final StudentStatus status;
  final DateTime? moveOutDate;

  Student({
    required this.id,
    required this.pgId,
    this.bedId,
    this.bedLabel,
    required this.fullName,
    required this.phone,
    this.email,
    this.guardianName,
    this.guardianPhone,
    this.permanentAddress,
    this.idProofNumber,
    required this.dateOfJoining,
    required this.status,
    this.moveOutDate,
  });

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        pgId: json['pgId'] as String,
        bedId: json['bedId'] as String?,
        bedLabel: json['bedLabel'] as String?,
        fullName: json['fullName'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
        guardianName: json['guardianName'] as String?,
        guardianPhone: json['guardianPhone'] as String?,
        permanentAddress: json['permanentAddress'] as String?,
        idProofNumber: json['idProofNumber'] as String?,
        dateOfJoining: DateTime.parse(json['dateOfJoining'] as String),
        status: StudentStatusX.fromApi(json['status'] as String),
        moveOutDate: json['moveOutDate'] != null ? DateTime.parse(json['moveOutDate'] as String) : null,
      );
}

/// A bed available for assignment, flattened out of the PG's Floor -> Room -> Bed tree.
class AvailableBed {
  final String id;
  final String label;
  final String roomNumber;
  final String floorName;

  AvailableBed({required this.id, required this.label, required this.roomNumber, required this.floorName});
}
