package com.pgplatform.notification;

import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.booking.BookingRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EngagementNotificationServiceTest {

    @Mock private DeviceTokenRepository deviceTokenRepository;
    @Mock private BookingRepository bookingRepository;
    @Mock private UserNotificationRepository notificationRepository;
    @Mock private NotificationService notificationService;
    @Mock private JdbcTemplate jdbcTemplate;

    @Test
    void sendsAStableDiscoveryMessageToEligibleCustomers() {
        LocalDate date = LocalDate.of(2026, 11, 4);
        User user = scheduledUser(date);
        EngagementNotificationService service = service(date);
        when(deviceTokenRepository.findDistinctActiveUsersByRole(Role.STUDENT)).thenReturn(List.of(user));
        when(bookingRepository.countActiveConfirmedForUser(user.getId())).thenReturn(0L);
        when(notificationRepository
                .countByUserIdAndCategoryAndCreatedAtGreaterThanEqualAndDeletedAtIsNull(
                        eq(user.getId()), eq(NotificationCategory.DISCOVERY), any(Instant.class)))
                .thenReturn(0L);

        service.sendScheduledEngagements();

        EngagementNotificationService.Template template =
                EngagementNotificationService.templateFor(user, date);
        verify(notificationService).notifyUser(user.getId(), template.title(), template.message(),
                NotificationCategory.DISCOVERY, EngagementNotificationService.EXPLORE_ROUTE);
    }

    @Test
    void skipsCustomersWhoAlreadyHaveAnActiveStay() {
        LocalDate date = LocalDate.of(2026, 11, 4);
        User user = scheduledUser(date);
        EngagementNotificationService service = service(date);
        when(deviceTokenRepository.findDistinctActiveUsersByRole(Role.STUDENT)).thenReturn(List.of(user));
        when(bookingRepository.countActiveConfirmedForUser(user.getId())).thenReturn(1L);

        service.sendScheduledEngagements();

        verify(notificationService, never()).notifyUser(any(), any(), any(), any(), any());
    }

    @Test
    void dailyCapPreventsDuplicateCampaigns() {
        LocalDate date = LocalDate.of(2026, 11, 4);
        User user = scheduledUser(date);
        EngagementNotificationService service = service(date);
        when(deviceTokenRepository.findDistinctActiveUsersByRole(Role.STUDENT)).thenReturn(List.of(user));
        when(bookingRepository.countActiveConfirmedForUser(user.getId())).thenReturn(0L);
        when(notificationRepository
                .countByUserIdAndCategoryAndCreatedAtGreaterThanEqualAndDeletedAtIsNull(
                        eq(user.getId()), eq(NotificationCategory.DISCOVERY), any(Instant.class)))
                .thenReturn(1L);

        service.sendScheduledEngagements();

        verify(notificationService, never()).notifyUser(any(), any(), any(), any(), any());
    }

    private EngagementNotificationService service(LocalDate date) {
        Instant instant = date.atTime(18, 30).toInstant(ZoneOffset.ofHoursMinutes(5, 30));
        when(jdbcTemplate.queryForObject(
                "select pg_try_advisory_xact_lock(?)", Boolean.class,
                EngagementNotificationService.SCHEDULER_LOCK_ID)).thenReturn(true);
        return new EngagementNotificationService(deviceTokenRepository, bookingRepository,
                notificationRepository, notificationService, jdbcTemplate,
                Clock.fixed(instant, EngagementNotificationService.INDIA));
    }

    private User scheduledUser(LocalDate date) {
        for (int value = 1; value < 100; value++) {
            User user = new User();
            user.setId(new UUID(0, value));
            user.setRole(Role.STUDENT);
            user.setFullName("Customer");
            if (EngagementNotificationService.scheduledForToday(user, date)) return user;
        }
        throw new IllegalStateException("No deterministic schedule candidate found");
    }
}
