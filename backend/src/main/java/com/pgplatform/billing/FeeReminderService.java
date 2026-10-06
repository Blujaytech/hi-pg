package com.pgplatform.billing;

import com.pgplatform.notification.NotificationService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;

@Service
public class FeeReminderService {
    private static final ZoneId INDIA_ZONE = ZoneId.of("Asia/Kolkata");

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
        sendScheduledReminders(LocalDate.now(INDIA_ZONE));
    }

    void sendScheduledReminders(LocalDate today) {
        for (Fee fee : feeRepository.findAllByStatusNotAndDeletedAtIsNull(FeeStatus.PAID)) {
            LocalDate due = fee.effectiveDueDate();
            if (due == null) {
                continue;
            }

            boolean extended = fee.getExtendedDueDate() != null;
            long daysUntilDue = ChronoUnit.DAYS.between(today, due);
            String amount = fee.getAmount() == null ? "the pending amount" : "INR " + fee.getAmount();
            String customerName = fee.getStudent().getFullName();

            if (daysUntilDue == 3) {
                deliver(fee,
                        extended ? FeeNotificationType.EXTENSION_DUE_IN_3_DAYS : FeeNotificationType.DUE_IN_3_DAYS,
                        due, false,
                        null, null,
                        "Rent due in 3 days",
                        "Your rent balance of " + amount + " is due on " + due + ".");
            } else if (daysUntilDue == 1) {
                deliver(fee,
                        extended ? FeeNotificationType.EXTENSION_DUE_TOMORROW : FeeNotificationType.DUE_TOMORROW,
                        due, false,
                        null, null,
                        "Rent due tomorrow",
                        "Your rent balance of " + amount + " is due tomorrow (" + due + ").");
            } else if (daysUntilDue == 0) {
                deliver(fee,
                        extended ? FeeNotificationType.EXTENSION_DUE : FeeNotificationType.DUE_TODAY,
                        due, true,
                        "Rent due today",
                        customerName + " has rent due today.",
                        "Rent due today",
                        "Your rent balance of " + amount + " is due today.");
            } else if (daysUntilDue == -1) {
                deliver(fee,
                        extended ? FeeNotificationType.EXTENSION_OVERDUE_DAY_1 : FeeNotificationType.OVERDUE_DAY_1,
                        due, true,
                        "Rent overdue",
                        customerName + " has rent overdue by 1 day.",
                        "Rent payment overdue",
                        "Your rent balance of " + amount + " was due on " + due
                                + ". Please pay or contact your PG owner.");
            } else if (daysUntilDue == -3) {
                deliver(fee,
                        extended ? FeeNotificationType.EXTENSION_OVERDUE : FeeNotificationType.OVERDUE_DAY_3,
                        due, true,
                        "Rent overdue",
                        customerName + " has rent overdue by 3 days.",
                        "Rent payment overdue",
                        "Your rent balance of " + amount + " is 3 days overdue. Please pay or contact your PG owner.");
            } else if (daysUntilDue == -7) {
                deliver(fee,
                        extended ? FeeNotificationType.EXTENSION_OVERDUE_DAY_7 : FeeNotificationType.OVERDUE_DAY_7,
                        due, true,
                        "Rent overdue",
                        customerName + " has rent overdue by 7 days.",
                        "Rent payment overdue",
                        "Your rent balance of " + amount + " is 7 days overdue. Please contact your PG owner.");
            }
        }
    }

    private void deliver(Fee fee,
                         FeeNotificationType type,
                         LocalDate effectiveDueDate,
                         boolean notifyOwner,
                         String ownerTitle,
                         String ownerMessage,
                         String customerTitle,
                         String customerMessage) {
        if (deliveryRepository.existsByFeeIdAndNotificationTypeAndEffectiveDueDateAndDeletedAtIsNull(
                fee.getId(), type, effectiveDueDate)) {
            return;
        }

        if (notifyOwner && fee.getPg() != null && fee.getPg().getOwner() != null) {
            notificationService.notifyUser(fee.getPg().getOwner().getId(), ownerTitle, ownerMessage);
        }
        if (fee.getStudent() != null && fee.getStudent().getUser() != null) {
            notificationService.notifyUser(fee.getStudent().getUser().getId(), customerTitle, customerMessage);
        }

        FeeNotificationDelivery delivery = new FeeNotificationDelivery();
        delivery.setFee(fee);
        delivery.setNotificationType(type);
        delivery.setEffectiveDueDate(effectiveDueDate);
        delivery.setDeliveredAt(Instant.now());
        deliveryRepository.save(delivery);
    }
}
