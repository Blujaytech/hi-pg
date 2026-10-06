package com.pgplatform.auth;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import jakarta.persistence.LockModeType;

import java.util.Optional;
import java.util.List;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {
    Optional<User> findByEmailAndDeletedAtIsNull(String email);
    Optional<User> findByEmailIgnoreCaseAndDeletedAtIsNull(String email);
    Optional<User> findByPhoneAndDeletedAtIsNull(String phone);
    Optional<User> findByGoogleSubjectAndDeletedAtIsNull(String googleSubject);
    Optional<User> findByFirebaseSubjectAndDeletedAtIsNull(String firebaseSubject);
    Optional<User> findByIdAndDeletedAtIsNull(UUID id);
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<User> findLockedByIdAndDeletedAtIsNull(UUID id);
    boolean existsByEmailAndDeletedAtIsNull(String email);
    boolean existsByEmailIgnoreCaseAndDeletedAtIsNull(String email);
    boolean existsByPhoneAndDeletedAtIsNull(String phone);
    List<User> findAllByRoleAndDeletedAtIsNull(Role role);
}
