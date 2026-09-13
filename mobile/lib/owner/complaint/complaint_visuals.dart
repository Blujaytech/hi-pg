import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../shared/app_states.dart';
import 'complaint_models.dart';

/// How complaint enums look on screen; shared by the owner and student
/// complaint lists so a status reads the same on both sides.
extension ComplaintCategoryVisuals on ComplaintCategory {
  IconData get icon => switch (this) {
        ComplaintCategory.maintenance => Icons.home_repair_service_outlined,
        ComplaintCategory.cleanliness => Icons.cleaning_services_outlined,
        ComplaintCategory.noise => Icons.volume_up_outlined,
        ComplaintCategory.security => Icons.shield_outlined,
        ComplaintCategory.billing => Icons.receipt_long_outlined,
        ComplaintCategory.other => Icons.support_agent_outlined,
      };
}

extension ComplaintStatusVisuals on ComplaintStatus {
  StatusTone get tone => switch (this) {
        ComplaintStatus.open => StatusTone.warning,
        ComplaintStatus.inProgress => StatusTone.dark,
        ComplaintStatus.resolved => StatusTone.success,
        ComplaintStatus.closed => StatusTone.neutral,
      };
}

extension ComplaintPriorityVisuals on ComplaintPriority {
  Color get color => switch (this) {
        ComplaintPriority.low => AppColors.muted,
        ComplaintPriority.medium => AppColors.warning,
        ComplaintPriority.high => AppColors.danger,
      };
}
