package com.pgplatform.common;

/**
 * Thrown when an authenticated principal is valid but does not own / may not
 * act on the requested resource (e.g. an Owner touching another Owner's PG,
 * or a Student touching another Student's record). This is the explicit,
 * service-layer stand-in for Postgres RLS -- see docs/security.md.
 */
public class ForbiddenException extends RuntimeException {
    public ForbiddenException(String message) {
        super(message);
    }
}
