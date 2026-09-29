package com.pgplatform.owner;

import com.pgplatform.auth.*;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.owner.dto.OwnerClaimSuggestionResponse;
import com.pgplatform.owner.dto.PgInterestResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class PgClaimService {
    private final PgRepository pgRepository;
    private final PgOwnerContactRepository contactRepository;
    private final PgClaimRequestRepository claimRepository;
    private final PgInterestRequestRepository interestRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    public PgClaimService(PgRepository pgRepository, PgOwnerContactRepository contactRepository,
                          PgClaimRequestRepository claimRepository, PgInterestRequestRepository interestRepository,
                          UserRepository userRepository, NotificationService notificationService) {
        this.pgRepository = pgRepository;
        this.contactRepository = contactRepository;
        this.claimRepository = claimRepository;
        this.interestRepository = interestRepository;
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    public boolean hasInvitation(String mobile) {
        return contactRepository.existsByNormalizedMobileAndDeletedAtIsNull(PhoneNumbers.normalize(mobile));
    }

    @Transactional(readOnly = true)
    public List<OwnerClaimSuggestionResponse> suggestions(UUID ownerId) {
        User owner = requireOwner(ownerId);
        if (owner.getPhone() == null || !owner.isPhoneVerified()) {
            throw new ConflictException("Verify your invited mobile number to find your PG");
        }
        return contactRepository.findAllByNormalizedMobileAndDeletedAtIsNullOrderByCreatedAtDesc(
                        PhoneNumbers.normalize(owner.getPhone())).stream()
                .map(contact -> suggestion(contact.getPg(), ownerId))
                .toList();
    }

    @Transactional
    public OwnerClaimSuggestionResponse claim(UUID pgId, UUID ownerId) {
        User owner = requireOwner(ownerId);
        Pg pg = pgRepository.findLockedByIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("PG not found"));
        PgOwnerContact contact = contactRepository.findByPgIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("No owner invitation exists for this PG"));
        if (owner.getPhone() == null || !owner.isPhoneVerified()
                || !contact.getNormalizedMobile().equals(PhoneNumbers.normalize(owner.getPhone()))) {
            throw new ConflictException("Sign in with the mobile number invited for this PG");
        }
        if (pg.getStatus() != PgStatus.ACTIVE) {
            throw new ConflictException("This PG listing is not active");
        }
        if (pg.getOwner() != null && !pg.getOwner().getId().equals(ownerId)) {
            throw new ConflictException("This PG has already been claimed");
        }
        if (pg.getClaimStatus() == PgClaimStatus.CLAIMED && pg.getOwner() != null) {
            return suggestion(pg, ownerId);
        }
        claimRepository.findByPgIdAndStatusAndDeletedAtIsNull(pgId, PgClaimRequestStatus.PENDING)
                .filter(existing -> !existing.getClaimant().getId().equals(ownerId))
                .ifPresent(existing -> { throw new ConflictException("Another claim is awaiting review"); });

        PgClaimRequest claim = claimRepository.findByPgIdAndClaimantIdAndDeletedAtIsNull(pgId, ownerId)
                .orElseGet(PgClaimRequest::new);
        claim.setPg(pg);
        claim.setClaimant(owner);
        claim.setMatchedMobile(contact.getNormalizedMobile());
        claim.setStatus(PgClaimRequestStatus.PENDING);
        claim.setSubmittedAt(Instant.now());
        claim.setReviewedAt(null);
        claim.setReviewNote(null);
        claimRepository.save(claim);

        // Provisional ownership is needed to let this OTP-verified claimant upload
        // KYC. Public booking remains disabled until the administrator approves it.
        pg.setOwner(owner);
        pg.setClaimStatus(PgClaimStatus.CLAIM_PENDING);
        pg.setVerificationStatus(PgVerificationStatus.UNVERIFIED);
        pg.setBookingEnabled(false);
        pgRepository.save(pg);
        contact.setInvitationStatus(PgInvitationStatus.CLAIMED);
        contactRepository.save(contact);
        return suggestion(pg, ownerId);
    }

    @Transactional
    public PgInterestResponse registerInterest(UUID pgId, UUID customerId) {
        User customer = userRepository.findByIdAndDeletedAtIsNull(customerId)
                .filter(user -> user.getRole() == Role.STUDENT)
                .orElseThrow(() -> new NotFoundException("Customer account not found"));
        Pg pg = pgRepository.findLockedByIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("PG not found"));
        if (pg.getStatus() != PgStatus.ACTIVE) {
            throw new NotFoundException("PG not found");
        }
        if (pg.getVerificationStatus() == PgVerificationStatus.VERIFIED && pg.isBookingEnabled()) {
            throw new ConflictException("This PG is already verified and accepting bookings");
        }
        PgInterestRequest interest = interestRepository
                .findByPgIdAndCustomerIdAndDeletedAtIsNull(pgId, customerId)
                .orElseGet(PgInterestRequest::new);
        boolean created = interest.getId() == null;
        interest.setPg(pg);
        interest.setCustomer(customer);
        interest = interestRepository.save(interest);
        if (created && pg.getOwner() != null) {
            notificationService.notifyUser(pg.getOwner().getId(), "A customer wants this PG verified",
                    "A customer is interested in " + pg.getName() + ". Complete KYC to enable bookings.");
        }
        return new PgInterestResponse(pgId, true,
                interestRepository.countByPgIdAndDeletedAtIsNull(pgId), interest.getCreatedAt());
    }

    private OwnerClaimSuggestionResponse suggestion(Pg pg, UUID ownerId) {
        return new OwnerClaimSuggestionResponse(pg.getId(), pg.getName(), pg.getAddress(), pg.getCity(),
                pg.getClaimStatus(), pg.getVerificationStatus(),
                interestRepository.countByPgIdAndDeletedAtIsNull(pg.getId()),
                pg.getOwner() != null && pg.getOwner().getId().equals(ownerId));
    }

    private User requireOwner(UUID ownerId) {
        return userRepository.findByIdAndDeletedAtIsNull(ownerId)
                .filter(user -> user.getRole() == Role.OWNER)
                .orElseThrow(() -> new NotFoundException("Owner account not found"));
    }
}
