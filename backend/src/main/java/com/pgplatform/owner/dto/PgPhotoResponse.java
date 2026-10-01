package com.pgplatform.owner.dto;

import java.util.UUID;

public record PgPhotoResponse(UUID id, String url, boolean cover, int displayOrder) { }
