package com.pgplatform.billing;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface FeeExtensionRepository extends JpaRepository<FeeExtension, UUID> {
}
