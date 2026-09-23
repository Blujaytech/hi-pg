package com.pgplatform.owner;

import com.pgplatform.common.ConflictException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.onboarding.OwnerKycStatus;
import com.pgplatform.onboarding.OwnerKycSubmission;
import com.pgplatform.onboarding.OwnerKycSubmissionRepository;
import com.pgplatform.owner.dto.DirectPaymentSettingsResponse;
import com.pgplatform.owner.dto.DirectPaymentSettingsUpdateRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
public class DirectPaymentSettingsService {
    private final PgDirectPaymentSettingsRepository repository;
    private final PgService pgService;
    private final OwnerKycSubmissionRepository kycRepository;

    public DirectPaymentSettingsService(PgDirectPaymentSettingsRepository repository, PgService pgService,
                                        OwnerKycSubmissionRepository kycRepository) {
        this.repository = repository;
        this.pgService = pgService;
        this.kycRepository = kycRepository;
    }

    @Transactional(readOnly = true)
    public DirectPaymentSettingsResponse get(UUID pgId, UUID ownerId) {
        Pg pg = pgService.requireOwnedPg(pgId, ownerId);
        return repository.findByPgIdAndDeletedAtIsNull(pgId)
                .map(DirectPaymentSettingsResponse::from)
                .orElseGet(() -> DirectPaymentSettingsResponse.unconfigured(pg));
    }

    @Transactional
    public DirectPaymentSettingsResponse update(UUID pgId, UUID ownerId,
                                                DirectPaymentSettingsUpdateRequest request) {
        Pg pg = pgService.requireOwnedPg(pgId, ownerId);
        PgDirectPaymentSettings settings = repository.findByPgIdAndDeletedAtIsNull(pgId)
                .orElseGet(() -> {
                    PgDirectPaymentSettings created = new PgDirectPaymentSettings();
                    created.setPg(pg);
                    return created;
                });
        if (request.enabled()) {
            OwnerKycSubmission kyc = kycRepository.findByPgIdAndDeletedAtIsNull(pgId)
                    .orElseThrow(() -> new ConflictException("Verified owner KYC is required for direct payments"));
            if (kyc.getStatus() != OwnerKycStatus.VERIFIED) {
                throw new ConflictException("Verified owner KYC is required for direct payments");
            }
            settings.setVerified(true);
            settings.setVerifiedAt(Instant.now());
        } else {
            settings.setVerified(false);
            settings.setVerifiedAt(null);
        }
        settings.setEnabled(request.enabled());
        settings.setBeneficiaryName(request.beneficiaryName().trim());
        settings.setUpiId(request.upiId().trim());
        settings.setMobileNumber(request.mobileNumber().trim());
        return DirectPaymentSettingsResponse.from(repository.save(settings));
    }

    @Transactional(readOnly = true)
    public PgDirectPaymentSettings requireEnabled(UUID pgId) {
        PgDirectPaymentSettings settings = requireSettings(pgId);
        if (!settings.isEnabled() || !settings.isVerified()) {
            throw new ConflictException("Direct owner payments are not enabled for this PG");
        }
        return settings;
    }

    private PgDirectPaymentSettings requireSettings(UUID pgId) {
        return repository.findByPgIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("Direct-payment settings are not configured for this PG"));
    }

}
