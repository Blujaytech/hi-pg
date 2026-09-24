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
import com.pgplatform.document.DocumentStorageGateway;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.time.Duration;

@Service
public class PgService {

    private final PgRepository pgRepository;
    private final UserRepository userRepository;
    private final OwnerKycSubmissionRepository ownerKycSubmissionRepository;
    private final DocumentStorageGateway storageGateway;

    public PgService(PgRepository pgRepository, UserRepository userRepository,
                     OwnerKycSubmissionRepository ownerKycSubmissionRepository,
                     DocumentStorageGateway storageGateway) {
        this.pgRepository = pgRepository;
        this.userRepository = userRepository;
        this.ownerKycSubmissionRepository = ownerKycSubmissionRepository;
        this.storageGateway = storageGateway;
    }

    @Transactional
    public PgResponse create(UUID ownerId, PgCreateRequest request) {
        User owner = userRepository.findByIdAndDeletedAtIsNull(ownerId)
                .orElseThrow(() -> new NotFoundException("Owner account not found"));

        Pg pg = new Pg();
        pg.setOwner(owner);
        pg.setName(request.name());
        pg.setAddress(request.address());
        pg.setCity(SupportedCities.requireCanonical(request.city()));
        pg.setState(request.state());
        pg.setPincode(request.pincode());
        pg.setLatitude(request.latitude());
        pg.setLongitude(request.longitude());
        pg.setDescription(request.description());
        pg.setGenderPreference(request.genderPreference());

        return response(pgRepository.save(pg));
    }

    @Transactional(readOnly = true)
    public List<PgResponse> listForOwner(UUID ownerId) {
        return pgRepository.findAllByOwnerIdAndDeletedAtIsNullOrderByCreatedAtDesc(ownerId)
                .stream().map(this::response).toList();
    }

    @Transactional(readOnly = true)
    public PgResponse getOwned(UUID pgId, UUID ownerId) {
        Pg pg = requireOwnedPg(pgId, ownerId);
        return response(pg);
    }

    @Transactional
    public PgResponse update(UUID pgId, UUID ownerId, PgUpdateRequest request) {
        Pg pg = requireOwnedPg(pgId, ownerId);
        pg.setName(request.name());
        pg.setAddress(request.address());
        pg.setCity(SupportedCities.requireCanonical(request.city()));
        pg.setState(request.state());
        pg.setPincode(request.pincode());
        pg.setLatitude(request.latitude());
        pg.setLongitude(request.longitude());
        pg.setDescription(request.description());
        pg.setGenderPreference(request.genderPreference());
        pg.setStatus(request.status());
        return response(pgRepository.save(pg));
    }

    @Transactional
    public PgResponse uploadPhoto(UUID pgId, UUID ownerId, byte[] content, String fileName, String contentType) {
        Pg pg = requireOwnedPg(pgId, ownerId);
        validatePhoto(content, fileName, contentType);
        String newKey = storageGateway.store(content, "pg-" + pgId + "-" + fileName, contentType);
        String oldKey = pg.getPhotoStorageKey();
        pg.setPhotoStorageKey(newKey);
        Pg saved = pgRepository.save(pg);
        if (oldKey != null && !oldKey.isBlank()) {
            storageGateway.delete(oldKey);
        }
        return response(saved);
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
        return response(pgRepository.save(pg));
    }

    @Transactional(readOnly = true)
    public List<PgResponse> listPendingPaymentOnboarding() {
        return pgRepository.findAllByPaymentOnboardingStatusAndDeletedAtIsNullOrderByCreatedAtAsc(
                PaymentOnboardingStatus.PENDING).stream().map(this::response).toList();
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
        return response(pgRepository.save(pg));
    }

    /** Public: FloorService/RoomService/BedService (same package) and StudentService (student package)
     * all reuse this instead of duplicating the lookup+ownership check. */
    public Pg requireOwnedPg(UUID pgId, UUID ownerId) {
        Pg pg = pgRepository.findByIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("PG not found"));
        OwnershipGuard.requireOwns(pg, ownerId);
        return pg;
    }

    private PgResponse response(Pg pg) {
        String photoUrl = pg.getPhotoStorageKey() == null ? null
                : storageGateway.generateSignedUrl(pg.getPhotoStorageKey(), Duration.ofHours(1));
        return PgResponse.from(pg, photoUrl);
    }

    private void validatePhoto(byte[] content, String fileName, String contentType) {
        if (content == null || content.length == 0 || content.length > 5L * 1024 * 1024) {
            throw new ConflictException("PG photo must be between 1 byte and 5 MB");
        }
        if (fileName == null || fileName.isBlank()) {
            throw new ConflictException("Photo file name is required");
        }
        boolean jpeg = "image/jpeg".equals(contentType) && content.length >= 3
                && (content[0] & 0xff) == 0xff && (content[1] & 0xff) == 0xd8 && (content[2] & 0xff) == 0xff;
        boolean png = "image/png".equals(contentType) && content.length >= 8
                && (content[0] & 0xff) == 0x89 && content[1] == 0x50 && content[2] == 0x4e && content[3] == 0x47;
        if (!jpeg && !png) {
            throw new ConflictException("PG photo must be a valid JPG or PNG image");
        }
    }
}
