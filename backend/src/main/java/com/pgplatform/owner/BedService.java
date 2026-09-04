package com.pgplatform.owner;

import com.pgplatform.common.NotFoundException;
import com.pgplatform.discovery.BedAvailabilityBroadcaster;
import com.pgplatform.owner.dto.BedResponse;
import com.pgplatform.owner.dto.BedStatusUpdateRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class BedService {

    private final BedRepository bedRepository;
    private final RoomService roomService;
    private final BedAvailabilityBroadcaster broadcaster;

    public BedService(BedRepository bedRepository, RoomService roomService, BedAvailabilityBroadcaster broadcaster) {
        this.bedRepository = bedRepository;
        this.roomService = roomService;
        this.broadcaster = broadcaster;
    }

    @Transactional(readOnly = true)
    public List<BedResponse> listForRoom(UUID roomId, UUID ownerId) {
        roomService.requireOwnedRoom(roomId, ownerId);
        return bedRepository.findAllByRoomIdAndDeletedAtIsNullOrderByLabelAsc(roomId)
                .stream().map(BedResponse::from).toList();
    }

    @Transactional
    public BedResponse updateStatus(UUID bedId, UUID ownerId, BedStatusUpdateRequest request) {
        Bed bed = bedRepository.findByIdAndDeletedAtIsNull(bedId)
                .orElseThrow(() -> new NotFoundException("Bed not found"));
        OwnershipGuard.requireOwns(bed, ownerId);

        bed.setStatus(request.status());
        BedResponse response = BedResponse.from(bedRepository.save(bed));
        broadcaster.notifyChanged(bed.getRoom().getFloor().getPg().getId());
        return response;
    }
}
