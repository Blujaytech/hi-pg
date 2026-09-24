package com.pgplatform.booking;

import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.booking.dto.BookingCreateRequest;
import com.pgplatform.booking.dto.BookingResponse;
import com.pgplatform.booking.dto.CalendarEntryResponse;
import com.pgplatform.booking.dto.MoveOutNoticeRequest;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.discovery.BedAvailabilityBroadcaster;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.owner.Bed;
import com.pgplatform.owner.BedRepository;
import com.pgplatform.owner.BedStatus;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgStatus;
import com.pgplatform.owner.Room;
import com.pgplatform.owner.RoomBookingMode;
import com.pgplatform.owner.RoomService;
import com.pgplatform.student.Student;
import com.pgplatform.student.CustomerProfileService;
import com.pgplatform.student.StudentRepository;
import com.pgplatform.student.StudentStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@Service
public class BookingService {

    private static final LocalDate OPEN_ENDED = LocalDate.of(9999, 12, 31);
    private static final long PAYMENT_HOLD_MINUTES = 10;
    private static final long MAX_DAY_WISE_NIGHTS = 27;
    private static final long MIN_MONTHLY_NIGHTS = 28;

    private final BookingRepository bookingRepository;
    private final BedRepository bedRepository;
    private final StudentRepository studentRepository;
    private final UserRepository userRepository;
    private final RoomService roomService;
    private final BedAvailabilityBroadcaster broadcaster;
    private final NotificationService notificationService;
    private final CustomerProfileService customerProfileService;

    public BookingService(BookingRepository bookingRepository, BedRepository bedRepository,
                          StudentRepository studentRepository, UserRepository userRepository,
                          RoomService roomService, BedAvailabilityBroadcaster broadcaster,
                          NotificationService notificationService,
                          CustomerProfileService customerProfileService) {
        this.bookingRepository = bookingRepository;
        this.bedRepository = bedRepository;
        this.studentRepository = studentRepository;
        this.userRepository = userRepository;
        this.roomService = roomService;
        this.broadcaster = broadcaster;
        this.notificationService = notificationService;
        this.customerProfileService = customerProfileService;
    }

    /**
     * Creates a ten-minute calendar hold. Confirmation happens only after a
     * captured Razorpay payment is verified by PaymentOrderService.
     */
    @Transactional
    public BookingResponse book(UUID userId, BookingCreateRequest request) {
        customerProfileService.requireEligible(userId, request.bookingType());
        expirePaymentHoldsInternal(Instant.now());

        Bed bed = bedRepository.findByIdForUpdate(request.bedId())
                .orElseThrow(() -> new NotFoundException("Bed not found"));
        Pg pg = bed.getRoom().getFloor().getPg();
        if (pg.getStatus() != PgStatus.ACTIVE) {
            throw new ConflictException("This PG is not currently accepting bookings");
        }
        if (bed.getStatus() == BedStatus.MAINTENANCE) {
            throw new ConflictException("That bed is under maintenance");
        }
        if (!bed.getBookingMode().supports(request.bookingType())) {
            throw new ConflictException("That bed does not support " + request.bookingType().name().toLowerCase() + " bookings");
        }

        validateDates(request);
        LocalDate requestedEnd = request.checkOutDate() == null ? OPEN_ENDED : request.checkOutDate();
        if (bookingRepository.countOverlappingForBed(bed.getId(), request.checkInDate(), requestedEnd) > 0) {
            throw new ConflictException("That bed is not available for the selected dates");
        }
        if (bookingRepository.countOverlappingForUser(userId, request.checkInDate(), requestedEnd) > 0) {
            throw new ConflictException("You already have a booking that overlaps these dates");
        }

        Student student = findOrCreateStudentForUser(userId, pg, request.checkInDate());
        Room room = bed.getRoom();
        BigDecimal rent = calculateRent(room, request);
        BigDecimal deposit = request.bookingType() == BookingType.MONTHLY
                ? room.getSecurityDeposit() : BigDecimal.ZERO;

        Booking booking = new Booking();
        booking.setStudent(student);
        booking.setBed(bed);
        booking.setPg(pg);
        booking.setStatus(BookingStatus.PAYMENT_PENDING);
        booking.setBookingType(request.bookingType());
        booking.setPaymentChannel(BookingPaymentChannel.UNSELECTED);
        booking.setMoveInDate(request.checkInDate());
        booking.setCheckOutDate(request.checkOutDate());
        booking.setCheckOutTime(request.bookingType() == BookingType.DAY_WISE
                ? request.checkOutTime() : null);
        booking.setRentAmount(rent);
        booking.setSecurityDepositAmount(deposit);
        booking.setTotalAmount(rent.add(deposit));
        booking.setPaymentExpiresAt(Instant.now().plusSeconds(PAYMENT_HOLD_MINUTES * 60));
        booking = bookingRepository.save(booking);

        broadcaster.notifyChanged(pg.getId());
        return BookingResponse.from(booking);
    }

    @Transactional
    public Booking confirmAfterCapturedPayment(UUID bookingId) {
        return confirmAfterPayment(bookingId, BookingPaymentChannel.RAZORPAY);
    }

    @Transactional
    public Booking confirmAfterDirectPayment(UUID bookingId) {
        return confirmAfterPayment(bookingId, BookingPaymentChannel.DIRECT_UPI);
    }

    private Booking confirmAfterPayment(UUID bookingId, BookingPaymentChannel expectedChannel) {
        Booking booking = requireBookingForUpdate(bookingId);
        if (booking.getStatus() == BookingStatus.CONFIRMED || booking.getStatus() == BookingStatus.CHECKED_IN) {
            if (booking.getPaymentChannel() != expectedChannel) {
                throw new ConflictException("This booking was confirmed through another payment channel");
            }
            return booking;
        }
        BookingStatus expectedStatus = expectedChannel == BookingPaymentChannel.DIRECT_UPI
                ? BookingStatus.DIRECT_PAYMENT_REVIEW : BookingStatus.PAYMENT_PENDING;
        if (booking.getStatus() != expectedStatus) {
            throw new ConflictException("This booking can no longer be confirmed");
        }
        if (booking.getPaymentChannel() == BookingPaymentChannel.UNSELECTED) {
            booking.setPaymentChannel(expectedChannel);
        } else if (booking.getPaymentChannel() != expectedChannel) {
            throw new ConflictException("This booking is using another payment channel");
        }
        if (expectedChannel == BookingPaymentChannel.RAZORPAY
                && booking.getPaymentExpiresAt() != null
                && booking.getPaymentExpiresAt().isBefore(Instant.now())) {
            booking.setStatus(BookingStatus.EXPIRED);
            bookingRepository.save(booking);
            throw new ConflictException("The booking hold expired before payment confirmation");
        }

        Bed bed = bedRepository.findByIdForUpdate(booking.getBed().getId())
                .orElseThrow(() -> new NotFoundException("Bed not found"));
        booking.setConfirmedAt(Instant.now());
        booking.setPaymentExpiresAt(null);

        Student student = booking.getStudent();
        if (!booking.getMoveInDate().isAfter(LocalDate.now())) {
            booking.setStatus(BookingStatus.CHECKED_IN);
            booking.setCheckedInAt(Instant.now());
            moveIntoPg(student, booking, bed);
        } else {
            // A future-dated booking is paid for but not yet lived in: the student stays
            // on their current PG's roster until transitionDueStays() checks them in.
            booking.setStatus(BookingStatus.CONFIRMED);
        }
        studentRepository.save(student);
        booking = bookingRepository.save(booking);

        broadcaster.notifyChanged(booking.getPg().getId());
        UUID userId = student.getUser() == null ? null : student.getUser().getId();
        notificationService.notifyUser(userId, "Booking confirmed",
                "You're booked into " + bed.getLabel() + " at " + booking.getPg().getName() +
                        ". Check-in: " + booking.getMoveInDate() + ".");
        notificationService.notifyUser(booking.getPg().getOwner().getId(), "New paid booking",
                student.getFullName() + " booked " + bed.getLabel() + " at " + booking.getPg().getName() + ".");
        return booking;
    }

    @Transactional
    public Booking claimOnlinePaymentChannel(UUID bookingId, UUID userId) {
        Booking booking = requireOwnedBookingForUpdate(bookingId, userId);
        requireLivePaymentHold(booking);
        if (booking.getPaymentChannel() == BookingPaymentChannel.DIRECT_UPI) {
            throw new ConflictException("Direct owner payment is already selected for this booking");
        }
        if (booking.getPaymentChannel() == BookingPaymentChannel.UNSELECTED) {
            booking.setPaymentChannel(BookingPaymentChannel.RAZORPAY);
            bookingRepository.save(booking);
        }
        return booking;
    }

    @Transactional
    public Booking claimDirectPaymentReview(UUID bookingId, UUID userId) {
        Booking booking = requireOwnedBookingForUpdate(bookingId, userId);
        requireLivePaymentHold(booking);
        if (booking.getPaymentChannel() != BookingPaymentChannel.DIRECT_UPI) {
            throw new ConflictException("Select direct owner payment before submitting a payment reference");
        }
        booking.setStatus(BookingStatus.DIRECT_PAYMENT_REVIEW);
        booking.setPaymentExpiresAt(null);
        return bookingRepository.save(booking);
    }

    @Transactional
    public Booking claimDirectPaymentChannel(UUID bookingId, UUID userId) {
        Booking booking = requireOwnedBookingForUpdate(bookingId, userId);
        requireLivePaymentHold(booking);
        if (booking.getPaymentChannel() == BookingPaymentChannel.RAZORPAY) {
            throw new ConflictException("Online payment is already selected for this booking");
        }
        if (booking.getPaymentChannel() == BookingPaymentChannel.UNSELECTED) {
            booking.setPaymentChannel(BookingPaymentChannel.DIRECT_UPI);
            bookingRepository.save(booking);
        }
        return booking;
    }

    @Transactional
    public Booking rejectDirectPayment(UUID bookingId, UUID ownerId, String reason) {
        Booking booking = requireBookingForUpdate(bookingId);
        if (!booking.getPg().getOwner().getId().equals(ownerId)) {
            throw new ForbiddenException("You do not have access to this booking");
        }
        if (booking.getStatus() != BookingStatus.DIRECT_PAYMENT_REVIEW
                || booking.getPaymentChannel() != BookingPaymentChannel.DIRECT_UPI) {
            throw new ConflictException("This booking is not awaiting direct-payment review");
        }
        booking.setStatus(BookingStatus.CANCELLED);
        booking.setCancelledAt(Instant.now());
        booking.setCancellationReason(reason);
        booking = bookingRepository.save(booking);
        broadcaster.notifyChanged(booking.getPg().getId());
        notificationService.notifyUser(booking.getStudent().getUser() == null ? null
                        : booking.getStudent().getUser().getId(),
                "Direct payment not approved", reason);
        return booking;
    }

    @Transactional(readOnly = true)
    public List<BookingResponse> listForUser(UUID userId) {
        return bookingRepository.findAllForUser(userId).stream().map(BookingResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public BookingResponse get(UUID bookingId, UUID userId) {
        return BookingResponse.from(requireOwnedByUser(bookingId, userId));
    }

    @Transactional(readOnly = true)
    public List<CalendarEntryResponse> calendarForRoom(UUID roomId, UUID ownerId, LocalDate from, LocalDate to) {
        roomService.requireOwnedRoom(roomId, ownerId);
        if (to == null || !to.isAfter(from)) {
            throw new ConflictException("Calendar end date must be after the start date");
        }
        return bookingRepository.findCalendarForRoom(roomId, from, to).stream()
                .map(CalendarEntryResponse::from).toList();
    }

    @Transactional
    public BookingResponse submitMoveOutNotice(UUID bookingId, UUID userId, MoveOutNoticeRequest request) {
        Booking booking = requireOwnedByUser(bookingId, userId);
        if (booking.getBookingType() != BookingType.MONTHLY) {
            throw new ConflictException("Move-out notice applies only to monthly stays");
        }
        if (booking.getStatus() != BookingStatus.CONFIRMED && booking.getStatus() != BookingStatus.CHECKED_IN) {
            throw new ConflictException("This booking is not an active monthly stay");
        }
        if (!request.plannedMoveOutDate().isAfter(booking.getMoveInDate())) {
            throw new ConflictException("Move-out date must be after the move-in date");
        }

        LocalDate today = LocalDate.now();
        long suppliedNotice = Math.max(0, ChronoUnit.DAYS.between(today, request.plannedMoveOutDate()));
        int requiredNotice = booking.getBed().getRoom().getNoticePeriodDays();
        booking.setNoticeGivenAt(Instant.now());
        booking.setPlannedMoveOutDate(request.plannedMoveOutDate());
        booking.setNoticeShortfallDays((int) Math.max(0, requiredNotice - suppliedNotice));
        booking.setCheckOutDate(request.plannedMoveOutDate());
        booking = bookingRepository.save(booking);

        notificationService.notifyUser(booking.getPg().getOwner().getId(), "Move-out notice received",
                booking.getStudent().getFullName() + " plans to leave on " + request.plannedMoveOutDate() +
                        ". Notice shortfall: " + booking.getNoticeShortfallDays() + " day(s).");
        return BookingResponse.from(booking);
    }

    @Transactional
    public BookingResponse cancel(UUID bookingId, UUID userId, String reason) {
        Booking booking = requireOwnedBookingForUpdate(bookingId, userId);
        if (booking.getStatus() == BookingStatus.CANCELLED || booking.getStatus() == BookingStatus.EXPIRED
                || booking.getStatus() == BookingStatus.COMPLETED) {
            throw new ConflictException("This booking is no longer active");
        }
        if (booking.getStatus() == BookingStatus.DIRECT_PAYMENT_REVIEW) {
            throw new ConflictException("A claimed direct payment must be reviewed by the owner before cancellation");
        }

        Bed bed = bedRepository.findByIdForUpdate(booking.getBed().getId())
                .orElseThrow(() -> new NotFoundException("Bed not found"));
        Student student = booking.getStudent();
        if (student.getBed() != null && student.getBed().getId().equals(bed.getId())) {
            student.setBed(null);
            student.setStatus(StudentStatus.MOVED_OUT);
            student.setMoveOutDate(LocalDate.now());
            studentRepository.save(student);
            bed.setStatus(BedStatus.AVAILABLE);
            bedRepository.save(bed);
        }

        booking.setStatus(BookingStatus.CANCELLED);
        booking.setCancelledAt(Instant.now());
        booking.setCancellationReason(reason);
        booking = bookingRepository.save(booking);

        broadcaster.notifyChanged(booking.getPg().getId());
        notificationService.notifyUser(booking.getPg().getOwner().getId(), "Booking cancelled",
                student.getFullName() + " cancelled their booking for " + bed.getLabel() + ".");
        return BookingResponse.from(booking);
    }

    @Scheduled(fixedDelayString = "${app.booking.hold-expiry-check-ms:60000}")
    @Transactional
    public void expirePaymentHolds() {
        expirePaymentHoldsInternal(Instant.now());
    }

    /** Keeps physical occupancy in sync with the date-range calendar. */
    @Scheduled(cron = "${app.booking.stay-transition-cron:0 5 * * * *}", zone = "Asia/Kolkata")
    @Transactional
    public void transitionDueStays() {
        LocalDate today = LocalDate.now();
        List<Booking> departures = bookingRepository
                .findAllByStatusInAndCheckOutDateLessThanEqualAndDeletedAtIsNull(
                        List.of(BookingStatus.CONFIRMED, BookingStatus.CHECKED_IN), today);
        for (Booking booking : departures) {
            if (isDepartureDue(booking, today, LocalTime.now())) {
                completeStay(booking);
            }
        }

        List<Booking> arrivals = bookingRepository
                .findAllByStatusAndMoveInDateLessThanEqualAndDeletedAtIsNull(BookingStatus.CONFIRMED, today);
        for (Booking booking : arrivals) {
            checkIn(booking);
        }
    }

    private void expirePaymentHoldsInternal(Instant now) {
        List<Booking> expired = bookingRepository
                .findAllByStatusAndPaymentExpiresAtBeforeAndDeletedAtIsNull(BookingStatus.PAYMENT_PENDING, now);
        expired.forEach(candidate -> expirePaymentHold(candidate.getId(), now));
    }

    private void expirePaymentHold(UUID bookingId, Instant now) {
        Booking booking = bookingRepository.findByIdForUpdate(bookingId).orElse(null);
        if (booking == null || booking.getStatus() != BookingStatus.PAYMENT_PENDING
                || booking.getPaymentExpiresAt() == null || !booking.getPaymentExpiresAt().isBefore(now)) return;
        booking.setStatus(BookingStatus.EXPIRED);
        bookingRepository.save(booking);
        broadcaster.notifyChanged(booking.getPg().getId());
    }

    private void completeStay(Booking booking) {
        Bed bed = bedRepository.findByIdForUpdate(booking.getBed().getId())
                .orElseThrow(() -> new NotFoundException("Bed not found"));
        Student student = booking.getStudent();
        if (student.getBed() != null && student.getBed().getId().equals(bed.getId())) {
            student.setBed(null);
            student.setStatus(StudentStatus.MOVED_OUT);
            student.setMoveOutDate(booking.getCheckOutDate());
            studentRepository.save(student);
            bed.setStatus(BedStatus.AVAILABLE);
            bedRepository.save(bed);
        }
        booking.setStatus(BookingStatus.COMPLETED);
        booking.setCompletedAt(Instant.now());
        bookingRepository.save(booking);
        broadcaster.notifyChanged(booking.getPg().getId());
    }

    private boolean isDepartureDue(Booking booking, LocalDate today, LocalTime now) {
        if (booking.getCheckOutDate() == null) return false;
        if (booking.getCheckOutDate().isBefore(today)) return true;
        if (booking.getCheckOutDate().isAfter(today)) return false;
        return booking.getBookingType() != BookingType.DAY_WISE
                || booking.getCheckOutTime() == null
                || !booking.getCheckOutTime().isAfter(now);
    }

    private void checkIn(Booking booking) {
        Bed bed = bedRepository.findByIdForUpdate(booking.getBed().getId())
                .orElseThrow(() -> new NotFoundException("Bed not found"));
        if (bed.getStatus() == BedStatus.MAINTENANCE || bed.getStatus() == BedStatus.OCCUPIED) {
            notificationService.notifyUser(booking.getPg().getOwner().getId(), "Check-in needs attention",
                    booking.getStudent().getFullName() + " is due to check in to " + bed.getLabel()
                            + ", but the bed is not available.");
            return;
        }
        Student student = booking.getStudent();
        moveIntoPg(student, booking, bed);
        studentRepository.save(student);
        booking.setStatus(BookingStatus.CHECKED_IN);
        booking.setCheckedInAt(Instant.now());
        bookingRepository.save(booking);
        broadcaster.notifyChanged(booking.getPg().getId());
        notificationService.notifyUser(student.getUser() == null ? null : student.getUser().getId(),
                "Check-in ready", "Your stay at " + booking.getPg().getName() + " starts today.");
    }

    /**
     * The single point where a student actually becomes a resident of a PG: on arrival,
     * not on booking. When they are moving in from another PG, the bed they were holding
     * there is released -- otherwise it stayed OCCUPIED with nobody in it and its owner
     * could never re-let it.
     */
    private void moveIntoPg(Student student, Booking booking, Bed bed) {
        Bed previousBed = student.getBed();
        if (previousBed != null && !previousBed.getId().equals(bed.getId())) {
            previousBed.setStatus(BedStatus.AVAILABLE);
            bedRepository.save(previousBed);
            broadcaster.notifyChanged(previousBed.getRoom().getFloor().getPg().getId());
        }
        student.setPg(booking.getPg());
        student.setDateOfJoining(booking.getMoveInDate());
        student.setStatus(StudentStatus.ACTIVE);
        student.setMoveOutDate(null);
        student.setBed(bed);
        bed.setStatus(BedStatus.OCCUPIED);
        bedRepository.save(bed);
    }

    private void validateDates(BookingCreateRequest request) {
        LocalDate checkIn = request.checkInDate();
        LocalDate checkOut = request.checkOutDate();
        if (checkIn.isBefore(LocalDate.now())) {
            throw new ConflictException("Check-in date cannot be in the past");
        }
        if (request.bookingType() == BookingType.DAY_WISE) {
            if (checkOut == null || !checkOut.isAfter(checkIn)) {
                throw new ConflictException("Day-wise bookings require a checkout date after check-in");
            }
            long nights = ChronoUnit.DAYS.between(checkIn, checkOut);
            if (nights > MAX_DAY_WISE_NIGHTS) {
                throw new ConflictException("Day-wise bookings can be at most " + MAX_DAY_WISE_NIGHTS + " nights");
            }
        } else if (checkOut != null && ChronoUnit.DAYS.between(checkIn, checkOut) < MIN_MONTHLY_NIGHTS) {
            throw new ConflictException("Monthly bookings must be at least " + MIN_MONTHLY_NIGHTS + " nights");
        }
    }

    private BigDecimal calculateRent(Room room, BookingCreateRequest request) {
        if (request.bookingType() == BookingType.MONTHLY) {
            return room.getRentPerBed();
        }
        if (room.getDayWiseRate() == null || room.getDayWiseRate().compareTo(BigDecimal.ZERO) <= 0) {
            throw new ConflictException("Day-wise pricing is not configured for this room");
        }
        long nights = ChronoUnit.DAYS.between(request.checkInDate(), request.checkOutDate());
        return room.getDayWiseRate().multiply(BigDecimal.valueOf(nights));
    }

    private Booking requireOwnedByUser(UUID bookingId, UUID userId) {
        Booking booking = requireBooking(bookingId);
        if (booking.getStudent().getUser() == null || !booking.getStudent().getUser().getId().equals(userId)) {
            throw new ForbiddenException("This booking does not belong to you");
        }
        return booking;
    }

    public Booking requireOwnedBooking(UUID bookingId, UUID userId) {
        return requireOwnedByUser(bookingId, userId);
    }

    public Booking requireOwnedBookingForUpdate(UUID bookingId, UUID userId) {
        Booking booking = requireBookingForUpdate(bookingId);
        if (booking.getStudent().getUser() == null || !booking.getStudent().getUser().getId().equals(userId)) {
            throw new ForbiddenException("This booking does not belong to you");
        }
        return booking;
    }

    private void requireLivePaymentHold(Booking booking) {
        if (booking.getStatus() != BookingStatus.PAYMENT_PENDING) {
            throw new ConflictException("This booking is not awaiting payment");
        }
        if (booking.getPaymentExpiresAt() != null && booking.getPaymentExpiresAt().isBefore(Instant.now())) {
            booking.setStatus(BookingStatus.EXPIRED);
            bookingRepository.save(booking);
            throw new ConflictException("The booking payment hold has expired");
        }
    }

    public Booking requireBooking(UUID bookingId) {
        return bookingRepository.findByIdAndDeletedAtIsNull(bookingId)
                .orElseThrow(() -> new NotFoundException("Booking not found"));
    }

    /** Row-locking variant, for callers that mutate a ledger keyed on this booking. */
    public Booking requireBookingForUpdate(UUID bookingId) {
        return bookingRepository.findByIdForUpdate(bookingId)
                .orElseThrow(() -> new NotFoundException("Booking not found"));
    }

    /**
     * A hold is an unpaid, ten-minute reservation, so it must not move the student's
     * record anywhere. Reassigning `pg` here handed the new PG's owner immediate access
     * to that student's fees and documents (ownership everywhere resolves through
     * `student.getPg().getOwner()`) and took the record away from the owner they are
     * actually still living with -- all without a rupee being paid. The transfer now
     * happens only on actual check-in, in {@link #moveIntoPg}.
     */
    private Student findOrCreateStudentForUser(UUID userId, Pg pg, LocalDate moveInDate) {
        return studentRepository.findByUserIdAndDeletedAtIsNull(userId)
                .orElseGet(() -> {
                    User user = userRepository.findByIdAndDeletedAtIsNull(userId)
                            .orElseThrow(() -> new NotFoundException("Student account not found"));
                    Student student = new Student();
                    student.setUser(user);
                    student.setPg(pg);
                    customerProfileService.applyToStudent(userId, student);
                    student.setDateOfJoining(moveInDate);
                    student.setStatus(StudentStatus.PROSPECTIVE);
                    return studentRepository.save(student);
                });
    }
}
