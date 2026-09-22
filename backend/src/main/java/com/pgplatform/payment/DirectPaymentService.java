package com.pgplatform.payment;

import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.booking.Booking;
import com.pgplatform.booking.BookingPaymentChannel;
import com.pgplatform.booking.BookingService;
import com.pgplatform.booking.BookingStatus;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.deposit.DepositService;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.owner.DirectPaymentSettingsService;
import com.pgplatform.owner.PgDirectPaymentSettings;
import com.pgplatform.owner.PgService;
import com.pgplatform.payment.dto.DirectPaymentApproveRequest;
import com.pgplatform.payment.dto.DirectPaymentDetailsResponse;
import com.pgplatform.payment.dto.DirectPaymentRejectRequest;
import com.pgplatform.payment.dto.DirectPaymentRequestResponse;
import com.pgplatform.payment.dto.DirectPaymentSubmitRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Service
public class DirectPaymentService {
    private final DirectPaymentRequestRepository repository;
    private final BookingService bookingService;
    private final DirectPaymentSettingsService settingsService;
    private final PgService pgService;
    private final UserRepository userRepository;
    private final DepositService depositService;
    private final NotificationService notificationService;

    @Value("${app.booking.direct-payment-review-minutes:120}")
    private long reviewMinutes;

    public DirectPaymentService(DirectPaymentRequestRepository repository, BookingService bookingService,
                                DirectPaymentSettingsService settingsService, PgService pgService,
                                UserRepository userRepository, DepositService depositService,
                                NotificationService notificationService) {
        this.repository = repository;
        this.bookingService = bookingService;
        this.settingsService = settingsService;
        this.pgService = pgService;
        this.userRepository = userRepository;
        this.depositService = depositService;
        this.notificationService = notificationService;
    }

    @Transactional(readOnly = true)
    public DirectPaymentDetailsResponse details(UUID bookingId, UUID userId) {
        Booking booking = bookingService.requireOwnedBooking(bookingId, userId);
        if (booking.getPaymentChannel() != BookingPaymentChannel.DIRECT_UPI) {
            throw new ConflictException("Direct owner payment has not been selected for this booking");
        }
        if (booking.getStatus() == BookingStatus.DIRECT_PAYMENT_REVIEW) {
            DirectPaymentRequest request = repository
                    .findFirstByBookingIdAndDeletedAtIsNullOrderByCreatedAtDesc(bookingId)
                    .orElseThrow(() -> new NotFoundException("No direct-payment request exists for this booking"));
            return new DirectPaymentDetailsResponse(booking.getId(), request.getBeneficiaryNameSnapshot(),
                    request.getUpiIdSnapshot(), mask(request.getMobileNumberSnapshot()),
                    request.getQuotedAmount(), request.getCurrency(), buildUpiUri(booking,
                    request.getBeneficiaryNameSnapshot(), request.getUpiIdSnapshot(), request.getQuotedAmount()), null);
        }
        return detailsForSelectedBooking(booking);
    }

    @Transactional
    public DirectPaymentDetailsResponse selectDirectPayment(UUID bookingId, UUID userId) {
        Booking preview = bookingService.requireOwnedBooking(bookingId, userId);
        settingsService.requireEnabled(preview.getPg().getId());
        Booking booking = bookingService.claimDirectPaymentChannel(bookingId, userId);
        return detailsForSelectedBooking(booking);
    }

    private DirectPaymentDetailsResponse detailsForSelectedBooking(Booking booking) {
        if (booking.getStatus() != BookingStatus.PAYMENT_PENDING) {
            throw new ConflictException("This booking is not awaiting payment");
        }
        if (booking.getPaymentExpiresAt() != null && booking.getPaymentExpiresAt().isBefore(Instant.now())) {
            throw new ConflictException("The booking payment hold has expired");
        }
        PgDirectPaymentSettings settings = settingsService.requireEnabled(booking.getPg().getId());
        return new DirectPaymentDetailsResponse(booking.getId(), settings.getBeneficiaryName(), settings.getUpiId(),
                mask(settings.getMobileNumber()), booking.getTotalAmount(), "INR",
                buildUpiUri(booking, settings.getBeneficiaryName(), settings.getUpiId(), booking.getTotalAmount()),
                booking.getPaymentExpiresAt());
    }

    @Transactional
    public DirectPaymentRequestResponse submit(UUID bookingId, UUID userId, DirectPaymentSubmitRequest input) {
        String idempotencyKey = input.idempotencyKey().trim();
        DirectPaymentRequest existing = repository.findByIdempotencyKeyAndDeletedAtIsNull(idempotencyKey).orElse(null);
        if (existing != null) {
            requireCustomer(existing, bookingId, userId);
            return DirectPaymentRequestResponse.from(existing);
        }
        if (!input.paymentConfirmed()) {
            throw new ConflictException("Confirm the direct payment before informing the owner");
        }
        String reference = normalizeReference(input.transactionReference());
        Booking preview = bookingService.requireOwnedBooking(bookingId, userId);
        PgDirectPaymentSettings settings = settingsService.requireEnabled(preview.getPg().getId());
        DirectPaymentRequest prior = repository.findFirstByBookingIdAndDeletedAtIsNullOrderByCreatedAtDesc(bookingId)
                .orElse(null);
        if (prior != null) {
            throw new ConflictException("A direct-payment request already exists for this booking");
        }
        if (repository.existsByPgIdAndTransactionReferenceIgnoreCaseAndDeletedAtIsNull(
                preview.getPg().getId(), reference)) {
            throw new ConflictException("That transaction reference was already submitted for this PG");
        }

        Booking booking = bookingService.claimDirectPaymentReview(bookingId, userId);
        DirectPaymentRequest request = new DirectPaymentRequest();
        request.setBooking(booking);
        request.setPg(booking.getPg());
        request.setCustomer(booking.getStudent().getUser());
        request.setIdempotencyKey(idempotencyKey);
        request.setQuotedAmount(booking.getTotalAmount());
        request.setCurrency("INR");
        request.setTransactionReference(reference);
        request.setStatus(DirectPaymentStatus.PENDING);
        request.setSubmittedAt(Instant.now());
        request.setReviewDueAt(Instant.now().plus(reviewMinutes, ChronoUnit.MINUTES));
        request.setBeneficiaryNameSnapshot(settings.getBeneficiaryName());
        request.setUpiIdSnapshot(settings.getUpiId());
        request.setMobileNumberSnapshot(settings.getMobileNumber());
        request = repository.save(request);

        notificationService.notifyUser(booking.getPg().getOwner().getId(), "Direct payment needs review",
                booking.getStudent().getFullName() + " reports paying INR " + booking.getTotalAmount()
                        + " for " + booking.getBed().getLabel() + ". Reference: " + reference);
        notificationService.notifyUser(userId, "Owner informed",
                "The PG owner has been asked to verify your payment before the bed is allocated.");
        return DirectPaymentRequestResponse.from(request);
    }

    @Transactional(readOnly = true)
    public DirectPaymentRequestResponse currentForCustomer(UUID bookingId, UUID userId) {
        Booking booking = bookingService.requireOwnedBooking(bookingId, userId);
        DirectPaymentRequest request = repository.findFirstByBookingIdAndDeletedAtIsNullOrderByCreatedAtDesc(bookingId)
                .orElseThrow(() -> new NotFoundException("No direct-payment request exists for this booking"));
        if (!request.getBooking().getId().equals(booking.getId())) throw new ForbiddenException("Access denied");
        return DirectPaymentRequestResponse.from(request);
    }

    @Transactional(readOnly = true)
    public List<DirectPaymentRequestResponse> listForOwner(UUID ownerId, UUID pgId, DirectPaymentStatus status) {
        List<DirectPaymentRequest> requests;
        if (pgId != null) {
            pgService.requireOwnedPg(pgId, ownerId);
            requests = status == null
                    ? repository.findAllByPgIdAndDeletedAtIsNullOrderBySubmittedAtDesc(pgId)
                    : repository.findAllByPgIdAndStatusAndDeletedAtIsNullOrderBySubmittedAtDesc(pgId, status);
        } else {
            requests = repository.findForOwner(ownerId, status);
        }
        return requests.stream().map(DirectPaymentRequestResponse::from).toList();
    }

    @Transactional
    public DirectPaymentRequestResponse approve(UUID requestId, UUID ownerId, DirectPaymentApproveRequest input) {
        DirectPaymentRequest preview = requireOwner(repository.findByIdAndDeletedAtIsNull(requestId)
                .orElseThrow(() -> new NotFoundException("Direct-payment request not found")), ownerId);
        Booking booking = bookingService.requireBookingForUpdate(preview.getBooking().getId());
        requireBookingOwner(booking, ownerId);
        DirectPaymentRequest request = requireOwner(repository.findByIdForUpdate(requestId)
                .orElseThrow(() -> new NotFoundException("Direct-payment request not found")), ownerId);

        String decisionKey = input.idempotencyKey().trim();
        if (request.getStatus() == DirectPaymentStatus.APPROVED) {
            if (decisionKey.equals(request.getDecisionIdempotencyKey())) return DirectPaymentRequestResponse.from(request);
            throw new ConflictException("This payment request was already approved");
        }
        requireUnusedDecisionKey(request, decisionKey);
        if (request.getStatus() != DirectPaymentStatus.PENDING
                && request.getStatus() != DirectPaymentStatus.REVIEW_OVERDUE) {
            throw new ConflictException("This payment request can no longer be approved");
        }
        if (input.amountReceived().compareTo(request.getQuotedAmount()) != 0
                || input.amountReceived().compareTo(booking.getTotalAmount()) != 0) {
            throw new ConflictException("Confirmed amount must exactly match the immutable booking total of INR "
                    + booking.getTotalAmount());
        }

        User owner = userRepository.findByIdAndDeletedAtIsNull(ownerId)
                .orElseThrow(() -> new NotFoundException("Owner account not found"));
        request.setConfirmedAmount(input.amountReceived());
        request.setReviewedBy(owner);
        request.setReviewedAt(Instant.now());
        request.setDecisionIdempotencyKey(decisionKey);
        request.setReviewNote(trimToNull(input.note()));
        request.setStatus(DirectPaymentStatus.APPROVED);
        request = repository.save(request);

        Booking confirmed = bookingService.confirmAfterDirectPayment(booking.getId());
        depositService.recordCollected(confirmed);
        notificationService.notifyUser(request.getCustomer().getId(), "Direct payment approved",
                "The owner verified INR " + input.amountReceived() + ". Your booking is confirmed.");
        return DirectPaymentRequestResponse.from(request);
    }

    @Transactional
    public DirectPaymentRequestResponse reject(UUID requestId, UUID ownerId, DirectPaymentRejectRequest input) {
        DirectPaymentRequest preview = requireOwner(repository.findByIdAndDeletedAtIsNull(requestId)
                .orElseThrow(() -> new NotFoundException("Direct-payment request not found")), ownerId);
        Booking booking = bookingService.requireBookingForUpdate(preview.getBooking().getId());
        requireBookingOwner(booking, ownerId);
        DirectPaymentRequest request = requireOwner(repository.findByIdForUpdate(requestId)
                .orElseThrow(() -> new NotFoundException("Direct-payment request not found")), ownerId);

        String decisionKey = input.idempotencyKey().trim();
        if (request.getStatus() == DirectPaymentStatus.REJECTED) {
            if (decisionKey.equals(request.getDecisionIdempotencyKey())) return DirectPaymentRequestResponse.from(request);
            throw new ConflictException("This payment request was already rejected");
        }
        requireUnusedDecisionKey(request, decisionKey);
        if (request.getStatus() != DirectPaymentStatus.PENDING
                && request.getStatus() != DirectPaymentStatus.REVIEW_OVERDUE) {
            throw new ConflictException("This payment request can no longer be rejected");
        }

        User owner = userRepository.findByIdAndDeletedAtIsNull(ownerId)
                .orElseThrow(() -> new NotFoundException("Owner account not found"));
        request.setReviewedBy(owner);
        request.setReviewedAt(Instant.now());
        request.setDecisionIdempotencyKey(decisionKey);
        request.setRejectionReason(input.reason().trim());
        request.setStatus(DirectPaymentStatus.REJECTED);
        request = repository.save(request);
        bookingService.rejectDirectPayment(booking.getId(), ownerId, input.reason().trim());
        return DirectPaymentRequestResponse.from(request);
    }

    @Scheduled(fixedDelayString = "${app.booking.direct-payment-review-check-ms:60000}")
    @Transactional
    public void markOverdueReviews() {
        List<DirectPaymentRequest> due = repository.findAllByStatusAndReviewDueAtBeforeAndDeletedAtIsNull(
                DirectPaymentStatus.PENDING, Instant.now());
        for (DirectPaymentRequest candidate : due) {
            DirectPaymentRequest request = repository.findByIdForUpdate(candidate.getId()).orElse(null);
            if (request == null || request.getStatus() != DirectPaymentStatus.PENDING
                    || request.getReviewDueAt().isAfter(Instant.now())) continue;
            request.setStatus(DirectPaymentStatus.REVIEW_OVERDUE);
            repository.save(request);
            notificationService.notifyUser(request.getPg().getOwner().getId(), "Direct payment review overdue",
                    "Verify booking payment reference " + request.getTransactionReference()
                            + ". The bed remains held until you approve or reject it.");
        }
    }

    private void requireUnusedDecisionKey(DirectPaymentRequest request, String key) {
        repository.findByDecisionIdempotencyKeyAndDeletedAtIsNull(key)
                .filter(other -> !other.getId().equals(request.getId()))
                .ifPresent(other -> { throw new ConflictException("That decision idempotency key is already in use"); });
    }

    private DirectPaymentRequest requireOwner(DirectPaymentRequest request, UUID ownerId) {
        requireBookingOwner(request.getBooking(), ownerId);
        return request;
    }

    private void requireBookingOwner(Booking booking, UUID ownerId) {
        if (!booking.getPg().getOwner().getId().equals(ownerId)) {
            throw new ForbiddenException("You do not have access to this payment request");
        }
    }

    private void requireCustomer(DirectPaymentRequest request, UUID bookingId, UUID userId) {
        if (!request.getBooking().getId().equals(bookingId) || !request.getCustomer().getId().equals(userId)) {
            throw new ForbiddenException("That idempotency key belongs to another payment request");
        }
    }

    private String normalizeReference(String value) {
        String reference = value.trim().toUpperCase(Locale.ROOT);
        if (!reference.matches("[A-Z0-9._/-]{6,100}")) {
            throw new ConflictException("Enter a valid UPI transaction reference");
        }
        return reference;
    }

    private String encode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20");
    }

    private String buildUpiUri(Booking booking, String beneficiaryName, String upiId, BigDecimal amount) {
        String note = "PG booking " + booking.getId();
        return "upi://pay?pa=" + encode(upiId)
                + "&pn=" + encode(beneficiaryName)
                + "&am=" + amount.toPlainString()
                + "&cu=INR&tn=" + encode(note);
    }

    private String mask(String value) {
        if (value == null || value.length() < 4) return "XXXX";
        return value.substring(0, 2) + "X".repeat(Math.max(4, value.length() - 4))
                + value.substring(value.length() - 2);
    }

    private String trimToNull(String value) { return value == null || value.isBlank() ? null : value.trim(); }
}
