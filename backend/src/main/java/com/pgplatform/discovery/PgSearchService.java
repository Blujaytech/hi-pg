package com.pgplatform.discovery;

import com.pgplatform.common.NotFoundException;
import com.pgplatform.common.PagedResponse;
import com.pgplatform.discovery.dto.FloorAvailabilityResponse;
import com.pgplatform.discovery.dto.AvailableBedSummary;
import com.pgplatform.discovery.dto.PgDetailsResponse;
import com.pgplatform.discovery.dto.PgSearchResultResponse;
import com.pgplatform.discovery.dto.RoomAvailabilityResponse;
import com.pgplatform.owner.BedRepository;
import com.pgplatform.owner.BedStatus;
import com.pgplatform.owner.Floor;
import com.pgplatform.owner.FloorRepository;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgRepository;
import com.pgplatform.owner.PgStatus;
import com.pgplatform.owner.Room;
import com.pgplatform.owner.RoomRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * Public (unauthenticated) student-facing discovery -- technical plan §6
 * Phase 9. Everything here reads across every owner's data indiscriminately
 * (that's the point of a public search) but only ever returns {@code
 * ACTIVE} PGs and never anything owner-only (contact details, students,
 * financials).
 */
@Service
public class PgSearchService {

    private static final int MAX_PAGE_SIZE = 50;

    private final PgRepository pgRepository;
    private final FloorRepository floorRepository;
    private final RoomRepository roomRepository;
    private final BedRepository bedRepository;

    public PgSearchService(PgRepository pgRepository, FloorRepository floorRepository,
                            RoomRepository roomRepository, BedRepository bedRepository) {
        this.pgRepository = pgRepository;
        this.floorRepository = floorRepository;
        this.roomRepository = roomRepository;
        this.bedRepository = bedRepository;
    }

    @Transactional(readOnly = true)
    public PagedResponse<PgSearchResultResponse> search(String city, GenderPreference genderPreference,
                                                          BigDecimal minRent, BigDecimal maxRent,
                                                          int page, int size) {
        Pageable pageable = PageRequest.of(Math.max(page, 0), clampSize(size), Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<Pg> results = pgRepository.search(blankToNull(city), genderPreference, minRent, maxRent, pageable);
        return PagedResponse.from(results, this::toSearchResult);
    }

    @Transactional(readOnly = true)
    public PgDetailsResponse getDetails(UUID pgId) {
        Pg pg = pgRepository.findByIdAndDeletedAtIsNullAndStatus(pgId, PgStatus.ACTIVE)
                .orElseThrow(() -> new NotFoundException("PG not found"));

        List<Floor> floors = floorRepository.findAllByPgIdAndDeletedAtIsNullOrderByFloorNumberAsc(pgId);
        long totalBeds = bedRepository.countByPgId(pgId);
        long availableBeds = bedRepository.countByPgIdAndStatus(pgId, BedStatus.AVAILABLE);

        List<FloorAvailabilityResponse> floorResponses = floors.stream().map(floor -> {
            List<Room> rooms = roomRepository.findAllByFloorIdAndDeletedAtIsNullOrderByRoomNumberAsc(floor.getId());
            List<RoomAvailabilityResponse> roomResponses = rooms.stream()
                    .map(room -> {
                        List<AvailableBedSummary> availableBedOptions = bedRepository
                                .findAllByRoomIdAndStatusAndDeletedAtIsNull(room.getId(), BedStatus.AVAILABLE)
                                .stream()
                                .map(bed -> new AvailableBedSummary(bed.getId(), bed.getLabel()))
                                .toList();
                        return new RoomAvailabilityResponse(
                                room.getId(), room.getRoomNumber(), room.getRoomType(), room.getSharingCount(),
                                room.getRentPerBed(), availableBedOptions.size(), availableBedOptions
                        );
                    })
                    .toList();
            return new FloorAvailabilityResponse(floor.getId(), floor.getName(), floor.getFloorNumber(), roomResponses);
        }).toList();

        return new PgDetailsResponse(
                pg.getId(), pg.getName(), pg.getAddress(), pg.getCity(), pg.getState(), pg.getPincode(),
                pg.getDescription(), pg.getGenderPreference(), pg.getLatitude(), pg.getLongitude(),
                totalBeds, availableBeds, floorResponses
        );
    }

    private PgSearchResultResponse toSearchResult(Pg pg) {
        long availableBeds = bedRepository.countByPgIdAndStatus(pg.getId(), BedStatus.AVAILABLE);
        BigDecimal minRent = roomRepository.findMinRentForPg(pg.getId());
        BigDecimal maxRent = roomRepository.findMaxRentForPg(pg.getId());
        return new PgSearchResultResponse(
                pg.getId(), pg.getName(), pg.getCity(), pg.getAddress(), pg.getDescription(),
                pg.getGenderPreference(), pg.getLatitude(), pg.getLongitude(),
                availableBeds, minRent, maxRent
        );
    }

    private int clampSize(int size) {
        if (size <= 0) return 20;
        return Math.min(size, MAX_PAGE_SIZE);
    }

    private String blankToNull(String value) {
        return (value == null || value.isBlank()) ? null : value.trim();
    }
}
