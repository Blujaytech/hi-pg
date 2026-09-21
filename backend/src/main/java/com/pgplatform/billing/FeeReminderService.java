package com.pgplatform.billing;

import com.pgplatform.notification.NotificationService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;

@Service
public class FeeReminderService {
    private final FeeRepository feeRepository;
    private final FeeNotificationDeliveryRepository deliveryRepository;
    private final NotificationService notificationService;

    public FeeReminderService(FeeRepository feeRepository,
                              FeeNotificationDeliveryRepository deliveryRepository,
                              NotificationService notificationService) {
        this.feeRepository = feeRepository;
        this.deliveryRepository = deliveryRepository;
        this.notificationService = notificationService;
    }

    @Scheduled(cron = "${app.billing.reminder-cron:0 0 9 * * *}", zone = "Asia/Kolkata")
    @Transactional
    public void sendScheduledReminders() {
        LocalDate today = LocalDate.now();
        for (Fee fee : feeRepository.findAllByStatusNotAndDeletedAtIsNull(FeeStatus.PAID)) {
            LocalDate due = fee.effectiveDueDate();
            boolean extended = fee.getExtendedDueDate() != null;
            if (today.equals(due)) {
                deliver(fee, extended ? FeeNotificationType.EXTENSION_DUE : FeeNotificationType.DUE_TODAY, due,
                        "Rent due today", fee.getStudent().getFullName() + " has rent due today.");
            } else if (today.equals(due.plusDays(3))) {
                deliver(fee, extended ? FeeNotificationType.EXTENSION_OVERDUE : FeeNotificationType.OVERDUE_DAY_3,
                        due, "Rent overdue", fee.getStudent().getFullName() + " has not paid rent due on " + due + ".");
            }
        }
    }

    private void deliver(Fee fee, FeeNotificationType type, LocalDate effectiveDueDate,
                         String ownerTitle, String ownerMessage) {
        if (deliveryRepository.existsByFeeIdAndNotificationTypeAndEffectiveDueDateAndDeletedAtIsNull(
                fee.getId(), type, effectiveDueDate)) {
            return;
        }
        notificationService.notifyUser(fee.getPg().getOwner().getId(), ownerTitle, ownerMessage);
        if (fee.getStudent().getUser() != null) {
            notificationService.notifyUser(fee.getStudent().getUser().getId(), ownerTitle,
                    "Your rent of INR " + fee.getAmount() + " is due on " + effectiveDueDate + ".");
        }
        FeeNotificationDelivery delivery = new FeeNotificationDelivery();
        delivery.setFee(fee);
        delivery.setNotificationType(type);
        delivery.setEffectiveDueDate(effectiveDueDate);
        delivery.setDeliveredAt(Instant.now());
        deliveryRepository.save(delivery);
    }
}
