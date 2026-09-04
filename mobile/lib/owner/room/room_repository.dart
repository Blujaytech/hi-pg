import '../../shared/api_client.dart';
import 'room_models.dart';

class RoomRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Room>> listForFloor(String floorId) async {
    final response = await _client.get<List<dynamic>>('/owner/floors/$floorId/rooms');
    return response.data!.map((e) => Room.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Room> create({
    required String floorId,
    required String roomNumber,
    required int sharingCount,
    required double rentPerBed,
    required RoomType roomType,
  }) async {
    final response = await _client.post<Map<String, dynamic>>('/owner/floors/$floorId/rooms', data: {
      'roomNumber': roomNumber,
      'sharingCount': sharingCount,
      'rentPerBed': rentPerBed,
      'roomType': roomType.apiValue,
    });
    return Room.fromJson(response.data!);
  }

  Future<Room> update(Room room, {required int sharingCount}) async {
    final response = await _client.put<Map<String, dynamic>>('/owner/rooms/${room.id}', data: {
      'roomNumber': room.roomNumber,
      'sharingCount': sharingCount,
      'rentPerBed': room.rentPerBed,
      'roomType': room.roomType.apiValue,
    });
    return Room.fromJson(response.data!);
  }

  Future<void> delete(String roomId) => _client.delete<void>('/owner/rooms/$roomId');
}
