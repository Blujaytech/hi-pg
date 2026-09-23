package com.pgplatform.owner;

import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.owner.dto.PgResponse;
import com.pgplatform.owner.dto.PgUpdateRequest;
import com.pgplatform.owner.dto.PaymentOnboardingReviewRequest;
import com.pgplatform.common.ConflictException;
import com.pgplatform.onboarding.OwnerKycStatus;
import com.pgplatform.onboarding.OwnerKycSubmissionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class PgService {

    private final PgRepository pgRepository;
    private final UserRepository userRepository;
    private final OwnerKycSubmissionRepository ownerKycSubmissionRepository;

    public PgService(PgRepository pgRepository, UserRepository userRepository,
                     OwnerKycSubmissionRepository ownerKycSubmissionRepository) {
        this.pgRepository = pgRepository;
        this.userRepository = userRepository;
        this.ownerKycSubmissionRepository = ownerKycSubmissionRepository;
    }

    @Transactional
    public PgResponse create(UUID ownerId, PgCreateRequest request) {
        User owner = userRepository.findByIdAndDeletedAtIsNull(ownerId)
                .orElseThrow(() -> new NotFoundException("Owner account not found"));

        Pg pg = new Pg();
        pg.setOwner(owner);
        pg.setName(request.name());
        pg.setAddress(request.address());
        pg.setCity(request.city());
        pg.setState(request.state());
        pg.setPincode(request.pincode());
        pg.setLatitude(request.latitude());
        pg.setLongitude(request.longitude());
        pg.setDescription(request.description());
        pg.setGenderPreference(request.genderPreference());

        return PgResponse.from(pgRepository.save(pg));
    }

    @Transactional(readOnly = true)
    public List<PgResponse> listForOwner(UUID ownerId) {
        return pgRepository.findAllByOwnerIdAndDeletedAtIsNullOrderByCreatedAtDesc(ownerId)
                .stream().map(PgResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public PgResponse getOwned(UUID pgId, UUID ownerId) {
        Pg pg = requireOwnedPg(pgId, ownerId);
        return PgResponse.from(pg);
    }

    @Transactional
    public PgResponse update(UUID pgId, UUID ownerId, PgUpdateRequest request) {
        Pg pg = requireOwnedPg(pgId, ownerId);
        pg.setName(request.name());
        pg.setAddress(request.address());
        pg.setCity(request.city());
        pg.setState(request.state());
        pg.setPincode(request.pincode());
        pg.setLatitude(request.latitude());
        pg.setLongitude(request.longitude());
        pg.setDescription(request.description());
        pg.setGenderPreference(request.genderPreference());
        pg.setStatus(request.status());
        return PgResponse.from(pgRepository.save(pg));
    }

    @Transactional
    public void delete(UUID pgId, UUID ownerId) {
        Pg pg = requireOwnedPg(pgId, ownerId);
        pg.markDeleted();
        pgRepository.save(pg);
    }

    @Transactional
    public PgResponse requestPaymentOnboarding(UUID pgId, UUID ownerId) {
        Pg pg = requireOwnedPg(pgId, ownerId);
        var kyc = ownerKycSubmissionRepository.findByPgIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new ConflictException("Complete the PG owner KYC profile first"));
        if (kyc.getStatus() != OwnerKycStatus.SUBMITTED && kyc.getStatus() != OwnerKycStatus.VERIFIED) {
            throw new ConflictException("Upload and submit all required KYC documents first");
        }
        if (pg.getPaymentOnboardingStatus() == PaymentOnboardingStatus.VERIFIED) {
            throw new ConflictException("Payments are already enabled for this PG");
        }
        pg.setPaymentOnboardingStatus(PaymentOnboardingStatus.PENDING);
        pg.setRazorpayLinkedAccountId(null);
        return PgResponse.from(pgRepository.save(pg));
    }

    @Transactional(readOnly = true)
    public List<PgResponse> listPendingPaymentOnboarding() {
        return pgRepository.findAllByPaymentOnboardingStatusAndDeletedAtIsNullOrderByCreatedAtAsc(
                PaymentOnboardingStatus.PENDING).stream().map(PgResponse::from).toList();
    }

    @Transactional
    public PgResponse reviewPaymentOnboarding(UUID pgId, PaymentOnboardingReviewRequest request) {
        Pg pg = pgRepository.findByIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("PG not found"));
        if (request.status() != PaymentOnboardingStatus.VERIFIED
                && request.status() != PaymentOnboardingStatus.REJECTED) {
            throw new ConflictException("Admin review must verify or reject the onboarding request");
        }
        if (request.status() == PaymentOnboardingStatus.VERIFIED
                && (request.razorpayLinkedAccountId() == null || request.razorpayLinkedAccountId().isBlank())) {
            throw new ConflictException("A Razorpay linked account is required before verification");
        }
        pg.setPaymentOnboardingStatus(request.status());
        pg.setRazorpayLinkedAccountId(request.status() == PaymentOnboardingStatus.VERIFIED
                ? request.razorpayLinkedAccountId().trim() : null);
        pg.setPlatformCommissionBps(request.platformCommissionBps());
        return PgResponse.from(pgRepository.save(pg));
    }

    /** Public: FloorService/RoomService/BedService (same package) and StudentService (student package)
     * all reuse this instead of duplicating the lookup+ownership check. */
    public Pg requireOwnedPg(UUID pgId, UUID ownerId) {
        Pg pg = pgRepository.findByIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("PG not found"));
        OwnershipGuard.requireOwns(pg, ownerId);
        return pg;
    }
}
