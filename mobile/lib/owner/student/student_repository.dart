import '../../shared/api_client.dart';
import '../bed/bed_models.dart';
import '../floor/floor_repository.dart';
import '../room/room_repository.dart';
import 'student_models.dart';

class StudentRepository {
  final ApiClient _client = ApiClient.instance;
  final _floorRepository = FloorRepository();
  final _roomRepository = RoomRepository();

  Future<List<Student>> listForPg(String pgId) async {
    final response = await _client.get<List<dynamic>>('/owner/pgs/$pgId/students');
    return response.data!.map((e) => Student.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Student> create({
    required String pgId,
    required String fullName,
    required String phone,
    String? email,
    String? guardianName,
    String? guardianPhone,
    String? permanentAddress,
    String? idProofNumber,
    required DateTime dateOfJoining,
    String? bedId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>('/owner/pgs/$pgId/students', data: {
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'guardianName': guardianName,
      'guardianPhone': guardianPhone,
      'permanentAddress': permanentAddress,
      'idProofNumber': idProofNumber,
      'dateOfJoining': dateOfJoining.toIso8601String().substring(0, 10),
      'bedId': bedId,
    });
    return Student.fromJson(response.data!);
  }

  Future<Student> assignBed(String studentId, String bedId) async {
    final response = await _client.post<Map<String, dynamic>>('/owner/students/$studentId/assign-bed', data: {
      'bedId': bedId,
    });
    return Student.fromJson(response.data!);
  }

  Future<Student> moveOut(String studentId) async {
    final response = await _client.post<Map<String, dynamic>>('/owner/students/$studentId/move-out');
    return Student.fromJson(response.data!);
  }

  Future<void> delete(String studentId) => _client.delete<void>('/owner/students/$studentId');

  /// Walks Floor -> Room -> Bed for a PG and returns only AVAILABLE beds, for
  /// the "assign a bed" picker. No single backend endpoint does this yet
  /// (see docs/decisions.md) -- fine at today's scale, worth revisiting if a
  /// PG grows to many floors/rooms.
  Future<List<AvailableBed>> listAvailableBeds(String pgId) async {
    final floors = await _floorRepository.listForPg(pgId);
    final beds = <AvailableBed>[];
    for (final floor in floors) {
      final rooms = await _roomRepository.listForFloor(floor.id);
      for (final room in rooms) {
        for (final bed in room.beds) {
          if (bed.status == BedStatus.available) {
            beds.add(AvailableBed(id: bed.id, label: bed.label, roomNumber: room.roomNumber, floorName: floor.name));
          }
        }
      }
    }
    return beds;
  }
}
