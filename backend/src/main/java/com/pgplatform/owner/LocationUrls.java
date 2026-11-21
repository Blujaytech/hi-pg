package com.pgplatform.owner;

import java.net.URI;
import java.util.Locale;
import java.util.Set;

public final class LocationUrls {
    private static final Set<String> GOOGLE_MAPS_HOSTS = Set.of(
            "maps.google.com", "www.google.com", "google.com", "maps.app.goo.gl", "goo.gl");

    private LocationUrls() { }

    public static String normalizeGoogleMapsUrl(String value) {
        if (value == null || value.isBlank()) return null;
        String candidate = value.trim();
        try {
            URI uri = URI.create(candidate);
            String host = uri.getHost() == null ? "" : uri.getHost().toLowerCase(Locale.ROOT);
            boolean allowedHost = GOOGLE_MAPS_HOSTS.contains(host) || host.endsWith(".google.com");
            boolean allowedPath = !host.equals("goo.gl") || uri.getPath().startsWith("/maps");
            if (!"https".equalsIgnoreCase(uri.getScheme()) || !allowedHost || !allowedPath) {
                throw new IllegalArgumentException("Location URL must be a secure Google Maps link");
            }
            return candidate;
        } catch (IllegalArgumentException error) {
            if ("Location URL must be a secure Google Maps link".equals(error.getMessage())) throw error;
            throw new IllegalArgumentException("Enter a valid Google Maps location URL");
        }
    }
}
