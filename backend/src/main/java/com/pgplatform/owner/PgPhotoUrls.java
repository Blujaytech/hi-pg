package com.pgplatform.owner;

import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import java.util.UUID;

public final class PgPhotoUrls {
    private static final String DATABASE_PREFIX = "database://pg-photo/";

    private PgPhotoUrls() { }

    public static String databaseStorageKey() {
        return DATABASE_PREFIX + UUID.randomUUID();
    }

    public static boolean isDatabaseStorageKey(String storageKey) {
        return storageKey != null && storageKey.startsWith(DATABASE_PREFIX);
    }

    public static String databaseUrl(PgPhoto photo) {
        return ServletUriComponentsBuilder.fromCurrentContextPath()
                .path("/api/v1/public/pgs/{pgId}/photos/{photoId}")
                .buildAndExpand(photo.getPg().getId(), photo.getId())
                .toUriString();
    }
}
