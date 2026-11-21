package com.pgplatform.notification;

import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, UUID> {
    List<DeviceToken> findAllByUserIdAndDeletedAtIsNull(UUID userId);
    Optional<DeviceToken> findByTokenAndDeletedAtIsNull(String token);

    @Query("select distinct d.user from DeviceToken d " +
            "where d.user.role = :role and d.user.status = 'ACTIVE' " +
            "and d.deletedAt is null and d.user.deletedAt is null")
    List<User> findDistinctActiveUsersByRole(@Param("role") Role role);
}
