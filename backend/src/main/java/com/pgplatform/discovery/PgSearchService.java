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
import com.pgplatform.owner.BedBookingMode;
import com.pgplatform.booking.BookingType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import java.time.LocalDate;
import java.util.Set;

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
    static final int MAX_QUERY_WORDS = 3;

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

    /**
     * {@code query} is free text matched word by word (case-insensitive,
     * partial) against the PG's name, address, city, state and pincode, so
     * "metro", "ameerpet ladies" or "500038" all work. Every word must match
     * somewhere; only the first {@value #MAX_QUERY_WORDS} words are used.
     * {@code city} stays an exact (case-insensitive) city filter for existing
     * clients.
     */
    @Transactional(readOnly = true)
    public PagedResponse<PgSearchResultResponse> search(String query, String city, GenderPreference genderPreference,
                                                          BigDecimal minRent, BigDecimal maxRent,
                                                          int page, int size) {
        Pageable pageable = PageRequest.of(Math.max(page, 0), clampSize(size), Sort.by(Sort.Direction.DESC, "createdAt"));
        List<String> words = likePatterns(query);
        Page<Pg> results = pgRepository.search(wordAt(words, 0), wordAt(words, 1), wordAt(words, 2),
                blankToNull(city), genderPreference, minRent, maxRent, pageable);
        return PagedResponse.from(results, this::toSearchResult);
    }

    /** Lower-cased {@code %word%} LIKE patterns, with LIKE wildcards escaped. */
    static List<String> likePatterns(String query) {
        if (query == null || query.isBlank()) return List.of();
        return Arrays.stream(query.trim().toLowerCase(Locale.ROOT).split("\\s+"))
                .limit(MAX_QUERY_WORDS)
                .map(word -> "%" + word.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%")
                .toList();
    }

    private static String wordAt(List<String> words, int index) {
        return index < words.size() ? words.get(index) : null;
    }

    @Transactional(readOnly = true)
    public PgDetailsResponse getDetails(UUID pgId, BookingType bookingType, LocalDate checkIn, LocalDate checkOut) {
        Pg pg = pgRepository.findByIdAndDeletedAtIsNullAndStatus(pgId, PgStatus.ACTIVE)
                .orElseThrow(() -> new NotFoundException("PG not found"));

        LocalDate requestedStart = checkIn == null ? LocalDate.now() : checkIn;
        LocalDate requestedEnd = checkOut != null ? checkOut
                : bookingType == BookingType.MONTHLY ? LocalDate.of(9999, 12, 31)
                : requestedStart.plusDays(1);
        if (!requestedEnd.isAfter(requestedStart)) {
            throw new com.pgplatform.common.ConflictException("Checkout date must be after check-in");
        }
        Set<BedBookingMode> modes = bookingType == null
                ? Set.of(BedBookingMode.MONTHLY, BedBookingMode.DAY_WISE, BedBookingMode.FLEXIBLE)
                : bookingType == BookingType.MONTHLY
                    ? Set.of(BedBookingMode.MONTHLY, BedBookingMode.FLEXIBLE)
                    : Set.of(BedBookingMode.DAY_WISE, BedBookingMode.FLEXIBLE);

        List<Floor> floors = floorRepository.findAllByPgIdAndDeletedAtIsNullOrderByFloorNumberAsc(pgId);
        long totalBeds = bedRepository.countByPgId(pgId);
        long availableBeds = bedRepository.countByPgIdAndStatus(pgId, BedStatus.AVAILABLE);

        List<FloorAvailabilityResponse> floorResponses = floors.stream().map(floor -> {
            List<Room> rooms = roomRepository.findAllByFloorIdAndDeletedAtIsNullOrderByRoomNumberAsc(floor.getId());
            List<RoomAvailabilityResponse> roomResponses = rooms.stream()
                    .map(room -> {
                        List<AvailableBedSummary> availableBedOptions = bedRepository
                                .findAvailableForDates(room.getId(), modes, requestedStart, requestedEnd)
                                .stream()
                                .map(bed -> new AvailableBedSummary(bed.getId(), bed.getLabel(), bed.getBookingMode()))
                                .toList();
                        return new RoomAvailabilityResponse(
                                room.getId(), room.getRoomNumber(), room.getRoomType(), room.getSharingCount(),
                                room.getRentPerBed(), room.getDayWiseRate(), room.getBookingMode(),
                                room.getNoticePeriodDays(), room.getSecurityDeposit(),
                                availableBedOptions.size(), availableBedOptions
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

    public PgDetailsResponse getDetails(UUID pgId) {
        return getDetails(pgId, null, null, null);
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
