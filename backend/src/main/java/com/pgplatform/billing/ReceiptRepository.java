package com.pgplatform.billing;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ReceiptRepository extends JpaRepository<Receipt, UUID> {
    Optional<Receipt> findByIdAndDeletedAtIsNull(UUID id);
    List<Receipt> findAllByStudentIdAndDeletedAtIsNullOrderByPaidOnDesc(UUID studentId);
    List<Receipt> findAllByPgIdAndDeletedAtIsNullOrderByPaidOnDesc(UUID pgId);

    /** Backs the human-readable receipt number (RCPT-<year>-<seq>) -- see ReceiptService. */
    @Query(value = "select nextval('receipt_number_seq')", nativeQuery = true)
    long nextSequenceValue();
}
