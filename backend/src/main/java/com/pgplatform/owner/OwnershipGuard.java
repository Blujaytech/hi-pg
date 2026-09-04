package com.pgplatform.owner;

import com.pgplatform.common.ForbiddenException;

import java.util.UUID;

/**
 * Explicit stand-in for Postgres RLS (technical plan §7 item 6): every method
 * here is called from a service before a mutation or a scoped read, and
 * throws if the resource's owner chain doesn't match the acting principal.
 * Every one of these checks needs a test proving cross-owner access fails --
 * see OwnershipGuardTest and docs/security.md.
 */
public final class OwnershipGuard {

    private OwnershipGuard() {
    }

    public static void requireOwns(Pg pg, UUID actingOwnerId) {
        if (!pg.getOwner().getId().equals(actingOwnerId)) {
            throw new ForbiddenException("You do not have access to this PG");
        }
    }

    public static void requireOwns(Floor floor, UUID actingOwnerId) {
        requireOwns(floor.getPg(), actingOwnerId);
    }

    public static void requireOwns(Room room, UUID actingOwnerId) {
        requireOwns(room.getFloor(), actingOwnerId);
    }

    public static void requireOwns(Bed bed, UUID actingOwnerId) {
        requireOwns(bed.getRoom(), actingOwnerId);
    }
}
