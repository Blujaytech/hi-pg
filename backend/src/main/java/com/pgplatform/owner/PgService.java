package com.pgplatform.owner;

import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.owner.dto.PgResponse;
import com.pgplatform.owner.dto.PgUpdateRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class PgService {

    private final PgRepository pgRepository;
    private final UserRepository userRepository;

    public PgService(PgRepository pgRepository, UserRepository userRepository) {
        this.pgRepository = pgRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public PgResponse create(UUID ownerId, PgCreateRequest request) {
        User owner = userRepository.findByIdAndDeletedAtIsNull(ownerId)
                .orElseThrow(() -> new NotFoundException("Owner account not found"));

        Pg pg = new Pg();
        pg.setOwner(owner);
        pg.setName(request.name());
        pg.setAddress(request.address());
        pg.setCity(request.city());
        pg.setState(request.state());
        pg.setPincode(request.pincode());
        pg.setLatitude(request.latitude());
        pg.setLongitude(request.longitude());
        pg.setDescription(request.description());
        pg.setGenderPreference(request.genderPreference());

        return PgResponse.from(pgRepository.save(pg));
    }

    @Transactional(readOnly = true)
    public List<PgResponse> listForOwner(UUID ownerId) {
        return pgRepository.findAllByOwnerIdAndDeletedAtIsNullOrderByCreatedAtDesc(ownerId)
                .stream().map(PgResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public PgResponse getOwned(UUID pgId, UUID ownerId) {
        Pg pg = requireOwnedPg(pgId, ownerId);
        return PgResponse.from(pg);
    }

    @Transactional
    public PgResponse update(UUID pgId, UUID ownerId, PgUpdateRequest request) {
        Pg pg = requireOwnedPg(pgId, ownerId);
        pg.setName(request.name());
        pg.setAddress(request.address());
        pg.setCity(request.city());
        pg.setState(request.state());
        pg.setPincode(request.pincode());
        pg.setLatitude(request.latitude());
        pg.setLongitude(request.longitude());
        pg.setDescription(request.description());
        pg.setGenderPreference(request.genderPreference());
        pg.setStatus(request.status());
        return PgResponse.from(pgRepository.save(pg));
    }

    @Transactional
    public void delete(UUID pgId, UUID ownerId) {
        Pg pg = requireOwnedPg(pgId, ownerId);
        pg.markDeleted();
        pgRepository.save(pg);
    }

    /** Public: FloorService/RoomService/BedService (same package) and StudentService (student package)
     * all reuse this instead of duplicating the lookup+ownership check. */
    public Pg requireOwnedPg(UUID pgId, UUID ownerId) {
        Pg pg = pgRepository.findByIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("PG not found"));
        OwnershipGuard.requireOwns(pg, ownerId);
        return pg;
    }
}
