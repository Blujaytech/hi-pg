import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/owner/complaint/complaint_models.dart';

void main() {
  test('parses a student complaint with property and resolution details', () {
    final complaint = Complaint.fromJson({
      'id': 'complaint-1',
      'studentId': 'student-1',
      'studentName': 'Asha Rao',
      'pgId': 'pg-1',
      'pgName': 'Metro Residency',
      'category': 'MAINTENANCE',
      'priority': 'HIGH',
      'description': 'The tap is leaking.',
      'status': 'RESOLVED',
      'resolutionNotes': 'The plumber replaced the tap.',
      'resolvedAt': '2026-09-12T10:30:00Z',
      'createdAt': '2026-09-11T08:00:00Z',
    });

    expect(complaint.pgName, 'Metro Residency');
    expect(complaint.category, ComplaintCategory.maintenance);
    expect(complaint.priority, ComplaintPriority.high);
    expect(complaint.status, ComplaintStatus.resolved);
    expect(complaint.resolutionNotes, 'The plumber replaced the tap.');
  });
}
