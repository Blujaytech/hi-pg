class DashboardSummary {
  final int totalPgs;
  final int totalFloors;
  final int totalRooms;
  final int totalBeds;
  final int occupiedBeds;
  final int availableBeds;
  final int maintenanceBeds;
  final double occupancyPercentage;
  final int totalActiveStudents;
  final double totalPendingDues;
  final double collectedThisMonth;
  final double expensesThisMonth;
  final double netThisMonth;
  final int openComplaints;

  DashboardSummary({
    required this.totalPgs,
    required this.totalFloors,
    required this.totalRooms,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.availableBeds,
    required this.maintenanceBeds,
    required this.occupancyPercentage,
    required this.totalActiveStudents,
    required this.totalPendingDues,
    required this.collectedThisMonth,
    required this.expensesThisMonth,
    required this.netThisMonth,
    required this.openComplaints,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        totalPgs: json['totalPgs'] as int,
        totalFloors: json['totalFloors'] as int,
        totalRooms: json['totalRooms'] as int,
        totalBeds: json['totalBeds'] as int,
        occupiedBeds: json['occupiedBeds'] as int,
        availableBeds: json['availableBeds'] as int,
        maintenanceBeds: json['maintenanceBeds'] as int,
        occupancyPercentage: (json['occupancyPercentage'] as num).toDouble(),
        totalActiveStudents: json['totalActiveStudents'] as int,
        totalPendingDues: (json['totalPendingDues'] as num).toDouble(),
        collectedThisMonth: (json['collectedThisMonth'] as num).toDouble(),
        expensesThisMonth: (json['expensesThisMonth'] as num).toDouble(),
        netThisMonth: (json['netThisMonth'] as num).toDouble(),
        openComplaints: json['openComplaints'] as int,
      );
}
