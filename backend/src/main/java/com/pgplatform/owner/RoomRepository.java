package com.pgplatform.owner;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface RoomRepository extends JpaRepository<Room, UUID> {
    Optional<Room> findByIdAndDeletedAtIsNull(UUID id);
    List<Room> findAllByFloorIdAndDeletedAtIsNullOrderByRoomNumberAsc(UUID floorId);

    @Query("select count(r) from Room r where r.floor.pg.id = :pgId and r.deletedAt is null")
    long countByPgId(@Param("pgId") UUID pgId);

    @Query("select count(r) from Room r where r.floor.pg.owner.id = :ownerId and r.deletedAt is null")
    long countByOwnerId(@Param("ownerId") UUID ownerId);

    @Query("select min(r.rentPerBed) from Room r where r.floor.pg.id = :pgId and r.deletedAt is null")
    java.math.BigDecimal findMinRentForPg(@Param("pgId") UUID pgId);

    @Query("select max(r.rentPerBed) from Room r where r.floor.pg.id = :pgId and r.deletedAt is null")
    java.math.BigDecimal findMaxRentForPg(@Param("pgId") UUID pgId);

    List<Room> findAllByFloorPgIdAndDeletedAtIsNullOrderByRoomNumberAsc(UUID pgId);
}
