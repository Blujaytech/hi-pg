package com.pgplatform.owner.dto;

import java.time.Instant;
import java.util.UUID;

public record PgInterestResponse(UUID pgId, boolean registered, long interestCount, Instant registeredAt) { }
