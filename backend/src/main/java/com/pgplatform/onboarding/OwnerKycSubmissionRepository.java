package com.pgplatform.onboarding;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface OwnerKycSubmissionRepository extends JpaRepository<OwnerKycSubmission, UUID> {
    Optional<OwnerKycSubmission> findByIdAndDeletedAtIsNull(UUID id);
    Optional<OwnerKycSubmission> findByPgIdAndDeletedAtIsNull(UUID pgId);
    List<OwnerKycSubmission> findAllByStatusAndDeletedAtIsNullOrderBySubmittedAtAsc(OwnerKycStatus status);
}
