package com.pgplatform.owner;

import com.pgplatform.common.ConflictException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.discovery.BedAvailabilityBroadcaster;
import com.pgplatform.owner.dto.BedResponse;
import com.pgplatform.owner.dto.RoomCreateRequest;
import com.pgplatform.owner.dto.RoomResponse;
import com.pgplatform.owner.dto.RoomUpdateRequest;
import com.pgplatform.student.Student;
import com.pgplatform.student.StudentRepository;
import com.pgplatform.student.StudentStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.dao.DataIntegrityViolationException;

import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import java.math.BigDecimal;

/**
 * Owns the Room <-> Bed relationship, in particular auto-creating/removing
 * beds so they always match a room's sharing_count (technical plan §6 Phase 2:
 * "bed auto-creation from room 'sharing' count, as the prototype does").
 */
@Service
public class RoomService {

    private final RoomRepository roomRepository;
    private final BedRepository bedRepository;
    private final FloorService floorService;
    private final BedAvailabilityBroadcaster broadcaster;
    private final StudentRepository studentRepository;

    public RoomService(RoomRepository roomRepository, BedRepository bedRepository, FloorService floorService,
                        BedAvailabilityBroadcaster broadcaster, StudentRepository studentRepository) {
        this.roomRepository = roomRepository;
        this.bedRepository = bedRepository;
        this.floorService = floorService;
        this.broadcaster = broadcaster;
        this.studentRepository = studentRepository;
    }

    @Transactional
    public RoomResponse create(UUID floorId, UUID ownerId, RoomCreateRequest request) {
        Floor floor = floorService.requireOwnedFloor(floorId, ownerId);
        validatePricing(request.bookingMode(), request.dayWiseRate());
        String roomNumber = normalizeRoomNumber(request.roomNumber());
        if (roomRepository.existsByFloorIdAndRoomNumberIgnoreCaseAndDeletedAtIsNull(floorId, roomNumber)) {
            throw new ConflictException("Room " + roomNumber + " already exists on this floor");
        }

        Room room = new Room();
        room.setFloor(floor);
        room.setRoomNumber(roomNumber);
        room.setSharingCount(request.sharingCount());
        room.setRentPerBed(request.rentPerBed());
        room.setRoomType(request.roomType());
        room.setBookingMode(request.bookingMode());
        room.setDayWiseRate(request.dayWiseRate());
        room.setNoticePeriodDays(request.noticePeriodDays());
        room.setSecurityDeposit(request.securityDeposit());
        try {
            room = roomRepository.saveAndFlush(room);
        } catch (DataIntegrityViolationException ex) {
            throw new ConflictException("Room " + roomNumber + " already exists on this floor");
        }

        List<Bed> beds = createBeds(room, 1, request.sharingCount());
        broadcaster.notifyChanged(floor.getPg().getId());
        return toResponse(room, beds);
    }

    @Transactional(readOnly = true)
    public List<RoomResponse> listForFloor(UUID floorId, UUID ownerId) {
        floorService.requireOwnedFloor(floorId, ownerId);
        return roomRepository.findAllByFloorIdAndDeletedAtIsNullOrderByRoomNumberAsc(floorId).stream()
                .map(room -> toResponse(room, bedRepository.findAllByRoomIdAndDeletedAtIsNullOrderByLabelAsc(room.getId())))
                .toList();
    }

    @Transactional
    public RoomResponse update(UUID roomId, UUID ownerId, RoomUpdateRequest request) {
        Room room = requireOwnedRoom(roomId, ownerId);
        validatePricing(request.bookingMode(), request.dayWiseRate());
        String roomNumber = normalizeRoomNumber(request.roomNumber());
        if (roomRepository.existsByFloorIdAndRoomNumberIgnoreCaseAndIdNotAndDeletedAtIsNull(
                room.getFloor().getId(), roomNumber, roomId)) {
            throw new ConflictException("Room " + roomNumber + " already exists on this floor");
        }
        RoomBookingMode previousMode = room.getBookingMode();
        room.setRoomNumber(roomNumber);
        room.setRentPerBed(request.rentPerBed());
        room.setRoomType(request.roomType());
        room.setBookingMode(request.bookingMode());
        room.setDayWiseRate(request.dayWiseRate());
        room.setNoticePeriodDays(request.noticePeriodDays());
        room.setSecurityDeposit(request.securityDeposit());

        int previousSharingCount = room.getSharingCount();
        room.setSharingCount(request.sharingCount());
        room = roomRepository.save(room);

        List<Bed> beds = syncBedsToSharingCount(room, previousSharingCount, request.sharingCount());
        if (request.bookingMode() != RoomBookingMode.MIXED || previousMode != RoomBookingMode.MIXED) {
            BedBookingMode inherited = inheritedBedMode(request.bookingMode());
            beds.forEach(bed -> {
                bed.setBookingMode(inherited);
                bedRepository.save(bed);
            });
        }
        broadcaster.notifyChanged(room.getFloor().getPg().getId());
        return toResponse(room, beds);
    }

    @Transactional
    public void delete(UUID roomId, UUID ownerId) {
        Room room = requireOwnedRoom(roomId, ownerId);
        bedRepository.findAllByRoomIdAndDeletedAtIsNullOrderByLabelAsc(roomId)
                .forEach(bed -> {
                    bed.markDeleted();
                    bedRepository.save(bed);
                });
        room.markDeleted();
        roomRepository.save(room);
        broadcaster.notifyChanged(room.getFloor().getPg().getId());
    }

    public Room requireOwnedRoom(UUID roomId, UUID ownerId) {
        Room room = roomRepository.findByIdAndDeletedAtIsNull(roomId)
                .orElseThrow(() -> new NotFoundException("Room not found"));
        OwnershipGuard.requireOwns(room, ownerId);
        return room;
    }

    private List<Bed> createBeds(Room room, int fromLabelIndex, int toLabelIndexInclusive) {
        for (int i = fromLabelIndex; i <= toLabelIndexInclusive; i++) {
            Bed bed = new Bed();
            bed.setRoom(room);
            bed.setLabel("Bed " + i);
            bed.setStatus(BedStatus.AVAILABLE);
            bed.setBookingMode(inheritedBedMode(room.getBookingMode()));
            bedRepository.save(bed);
        }
        return bedRepository.findAllByRoomIdAndDeletedAtIsNullOrderByLabelAsc(room.getId());
    }

    /**
     * Grows or shrinks the room's beds to match a new sharing count.
     * Growing: adds new AVAILABLE beds numbered after the current max.
     * Shrinking: removes (soft-deletes) the highest-numbered AVAILABLE beds
     * first; refuses if there aren't enough non-occupied beds to remove,
     * since an occupied bed can't just disappear from under a student.
     */
    private List<Bed> syncBedsToSharingCount(Room room, int previousCount, int newCount) {
        if (newCount == previousCount) {
            return bedRepository.findAllByRoomIdAndDeletedAtIsNullOrderByLabelAsc(room.getId());
        }

        if (newCount > previousCount) {
            return createBeds(room, previousCount + 1, newCount);
        }

        int toRemove = previousCount - newCount;
        List<Bed> removable = bedRepository.findAllByRoomIdAndStatusAndDeletedAtIsNull(room.getId(), BedStatus.AVAILABLE)
                .stream()
                .sorted(Comparator.comparing(Bed::getLabel).reversed())
                .toList();

        if (removable.size() < toRemove) {
            throw new ConflictException(
                    "Cannot reduce sharing count to " + newCount + ": " + (toRemove - removable.size()) +
                            " bed(s) are occupied. Move those students out first.");
        }

        for (int i = 0; i < toRemove; i++) {
            Bed bed = removable.get(i);
            bed.markDeleted();
            bedRepository.save(bed);
        }
        return bedRepository.findAllByRoomIdAndDeletedAtIsNullOrderByLabelAsc(room.getId());
    }

    private RoomResponse toResponse(Room room, List<Bed> beds) {
        List<BedResponse> bedResponses = beds.stream().map(bed -> {
            Student occupant = bed.getStatus() == BedStatus.OCCUPIED
                    ? studentRepository.findByBedIdAndStatusAndDeletedAtIsNull(bed.getId(), StudentStatus.ACTIVE).orElse(null)
                    : null;
            return BedResponse.from(bed, occupant);
        }).toList();
        return RoomResponse.from(room, bedResponses);
    }

    private void validatePricing(RoomBookingMode mode, BigDecimal dayWiseRate) {
        if ((mode == RoomBookingMode.DAY_WISE || mode == RoomBookingMode.MIXED)
                && (dayWiseRate == null || dayWiseRate.compareTo(BigDecimal.ZERO) <= 0)) {
            throw new ConflictException("A positive day-wise rate is required for day-wise or mixed rooms");
        }
    }

    private String normalizeRoomNumber(String value) {
        String normalized = value == null ? "" : value.trim().replaceAll("\\s+", " ");
        if (normalized.isEmpty()) throw new ConflictException("Room number is required");
        return normalized;
    }

    private BedBookingMode inheritedBedMode(RoomBookingMode mode) {
        return switch (mode) {
            case MONTHLY -> BedBookingMode.MONTHLY;
            case DAY_WISE -> BedBookingMode.DAY_WISE;
            case MIXED -> BedBookingMode.FLEXIBLE;
        };
    }
}
