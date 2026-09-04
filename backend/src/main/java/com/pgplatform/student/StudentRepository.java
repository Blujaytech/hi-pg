package com.pgplatform.student;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface StudentRepository extends JpaRepository<Student, UUID> {

    Optional<Student> findByIdAndDeletedAtIsNull(UUID id);

    List<Student> findAllByPgIdAndDeletedAtIsNullOrderByFullNameAsc(UUID pgId);

    Optional<Student> findByBedIdAndStatusAndDeletedAtIsNull(UUID bedId, StudentStatus status);

    @Query("select count(s) from Student s where s.pg.owner.id = :ownerId and s.status = 'ACTIVE' and s.deletedAt is null")
    long countActiveByOwnerId(@Param("ownerId") UUID ownerId);

    @Query("select count(s) from Student s where s.pg.id = :pgId and s.status = 'ACTIVE' and s.deletedAt is null")
    long countActiveByPgId(@Param("pgId") UUID pgId);

    Optional<Student> findByUserIdAndDeletedAtIsNull(UUID userId);
}
