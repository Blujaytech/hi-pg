export type OwnerSession = {
  authenticated: boolean;
  fullName?: string;
};

export type DashboardSummary = {
  totalPgs: number;
  totalFloors: number;
  totalRooms: number;
  totalBeds: number;
  occupiedBeds: number;
  availableBeds: number;
  maintenanceBeds: number;
  occupancyPercentage: number;
  totalActiveStudents: number;
  totalPendingDues: number;
  collectedThisMonth: number;
  expensesThisMonth: number;
  netThisMonth: number;
  openComplaints: number;
};

