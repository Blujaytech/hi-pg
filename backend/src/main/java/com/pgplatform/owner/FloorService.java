package com.pgplatform.owner;

import com.pgplatform.common.NotFoundException;
import com.pgplatform.owner.dto.FloorCreateRequest;
import com.pgplatform.owner.dto.FloorResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class FloorService {

    private final FloorRepository floorRepository;
    private final PgService pgService;

    public FloorService(FloorRepository floorRepository, PgService pgService) {
        this.floorRepository = floorRepository;
        this.pgService = pgService;
    }

    @Transactional
    public FloorResponse create(UUID pgId, UUID ownerId, FloorCreateRequest request) {
        Pg pg = pgService.requireOwnedPg(pgId, ownerId);

        Floor floor = new Floor();
        floor.setPg(pg);
        floor.setName(request.name());
        floor.setFloorNumber(request.floorNumber());

        return FloorResponse.from(floorRepository.save(floor));
    }

    @Transactional(readOnly = true)
    public List<FloorResponse> listForPg(UUID pgId, UUID ownerId) {
        pgService.requireOwnedPg(pgId, ownerId);
        return floorRepository.findAllByPgIdAndDeletedAtIsNullOrderByFloorNumberAsc(pgId)
                .stream().map(FloorResponse::from).toList();
    }

    @Transactional
    public FloorResponse update(UUID floorId, UUID ownerId, FloorCreateRequest request) {
        Floor floor = requireOwnedFloor(floorId, ownerId);
        floor.setName(request.name());
        floor.setFloorNumber(request.floorNumber());
        return FloorResponse.from(floorRepository.save(floor));
    }

    @Transactional
    public void delete(UUID floorId, UUID ownerId) {
        Floor floor = requireOwnedFloor(floorId, ownerId);
        floor.markDeleted();
        floorRepository.save(floor);
    }

    Floor requireOwnedFloor(UUID floorId, UUID ownerId) {
        Floor floor = floorRepository.findByIdAndDeletedAtIsNull(floorId)
                .orElseThrow(() -> new NotFoundException("Floor not found"));
        OwnershipGuard.requireOwns(floor, ownerId);
        return floor;
    }
}
