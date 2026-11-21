package com.pgplatform.notification;

import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.booking.BookingRepository;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.TemporalAdjusters;
import java.time.temporal.WeekFields;
import java.util.List;
import java.util.Objects;

@Service
@ConditionalOnProperty(name = "app.notifications.engagement-enabled", havingValue = "true")
public class EngagementNotificationService {

    static final ZoneId INDIA = ZoneId.of("Asia/Kolkata");
    static final String EXPLORE_ROUTE = "/student/search";
    static final int WEEKLY_LIMIT = 3;
    static final long SCHEDULER_LOCK_ID = 4849504744495343L;

    private static final List<Template> TEMPLATES = List.of(
            new Template("Roads are for rides 😉", "Not roommates. Find a verified bed near you."),
            new Template("Still PG hunting?", "Your pillow is getting impatient. Let us find it a room."),
            new Template("Your next room says hi 👋", "Fresh stays and available beds are waiting inside."),
            new Template("Don't ghost your search", "A comfortable PG could be one tap away."),
            new Template("Bed search, simplified", "Skip the random calls. Explore stays with clear details."),
            new Template("Plot twist: you found home", "Check today's PG options before someone takes the window bed."),
            new Template("New city, less panic", "Browse stays designed to feel a little more like home."),
            new Template("Your suitcase called", "It would like a proper room. Explore available PGs."),
            new Template("Roommates are optional", "A good room is not. See stays that match your routine."),
            new Template("Stop scrolling randomly", "Verified PG options are easier to compare inside HiPG."),
            new Template("A better bed is loading", "Open HiPG and continue your stay search."),
            new Template("Home is a search away", "See PGs, prices and availability without the guesswork."));

    private final DeviceTokenRepository deviceTokenRepository;
    private final BookingRepository bookingRepository;
    private final UserNotificationRepository notificationRepository;
    private final NotificationService notificationService;
    private final JdbcTemplate jdbcTemplate;
    private final Clock clock;

    @Autowired
    public EngagementNotificationService(DeviceTokenRepository deviceTokenRepository,
                                         BookingRepository bookingRepository,
                                         UserNotificationRepository notificationRepository,
                                         NotificationService notificationService,
                                         JdbcTemplate jdbcTemplate) {
        this(deviceTokenRepository, bookingRepository, notificationRepository,
                notificationService, jdbcTemplate, Clock.system(INDIA));
    }

    EngagementNotificationService(DeviceTokenRepository deviceTokenRepository,
                                  BookingRepository bookingRepository,
                                  UserNotificationRepository notificationRepository,
                                  NotificationService notificationService,
                                  JdbcTemplate jdbcTemplate,
                                  Clock clock) {
        this.deviceTokenRepository = deviceTokenRepository;
        this.bookingRepository = bookingRepository;
        this.notificationRepository = notificationRepository;
        this.notificationService = notificationService;
        this.jdbcTemplate = jdbcTemplate;
        this.clock = clock;
    }

    @Scheduled(cron = "${app.notifications.engagement-cron:0 30 18 * * *}", zone = "Asia/Kolkata")
    @Transactional
    public void sendScheduledEngagements() {
        Boolean lockAcquired = jdbcTemplate.queryForObject(
                "select pg_try_advisory_xact_lock(?)", Boolean.class, SCHEDULER_LOCK_ID);
        if (!Boolean.TRUE.equals(lockAcquired)) {
            return;
        }

        ZonedDateTime now = ZonedDateTime.now(clock.withZone(INDIA));
        LocalDate today = now.toLocalDate();
        Instant startOfDay = today.atStartOfDay(INDIA).toInstant();
        Instant startOfWeek = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
                .atStartOfDay(INDIA).toInstant();

        for (User user : deviceTokenRepository.findDistinctActiveUsersByRole(Role.STUDENT)) {
            if (!scheduledForToday(user, today) || bookingRepository.countActiveConfirmedForUser(user.getId()) > 0) {
                continue;
            }
            if (notificationRepository
                    .countByUserIdAndCategoryAndCreatedAtGreaterThanEqualAndDeletedAtIsNull(
                            user.getId(), NotificationCategory.DISCOVERY, startOfDay) > 0) {
                continue;
            }
            if (notificationRepository
                    .countByUserIdAndCategoryAndCreatedAtGreaterThanEqualAndDeletedAtIsNull(
                            user.getId(), NotificationCategory.DISCOVERY, startOfWeek) >= WEEKLY_LIMIT) {
                continue;
            }

            Template template = templateFor(user, today);
            notificationService.notifyUser(user.getId(), template.title(), template.message(),
                    NotificationCategory.DISCOVERY, EXPLORE_ROUTE);
        }
    }

    static boolean scheduledForToday(User user, LocalDate date) {
        int week = date.get(WeekFields.ISO.weekOfWeekBasedYear());
        int firstDay = Math.floorMod(Objects.hash(user.getId(), week), 7);
        int today = date.getDayOfWeek().getValue() - 1;
        return today == firstDay || today == (firstDay + 2) % 7 || today == (firstDay + 4) % 7;
    }

    static Template templateFor(User user, LocalDate date) {
        return TEMPLATES.get(Math.floorMod(Objects.hash(user.getId(), date), TEMPLATES.size()));
    }

    record Template(String title, String message) {}
}
