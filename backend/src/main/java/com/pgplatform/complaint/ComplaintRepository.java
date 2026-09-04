package com.pgplatform.complaint;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ComplaintRepository extends JpaRepository<Complaint, UUID> {
    Optional<Complaint> findByIdAndDeletedAtIsNull(UUID id);
    List<Complaint> findAllByStudentIdAndDeletedAtIsNullOrderByCreatedAtDesc(UUID studentId);
    List<Complaint> findAllByPgIdAndDeletedAtIsNullOrderByCreatedAtDesc(UUID pgId);

    @Query("select count(c) from Complaint c where c.pg.owner.id = :ownerId " +
           "and c.status in ('OPEN', 'IN_PROGRESS') and c.deletedAt is null")
    long countOpenByOwnerId(@Param("ownerId") UUID ownerId);

    @Query("select count(c) from Complaint c where c.pg.id = :pgId " +
           "and c.status in ('OPEN', 'IN_PROGRESS') and c.deletedAt is null")
    long countOpenByPgId(@Param("pgId") UUID pgId);
}
