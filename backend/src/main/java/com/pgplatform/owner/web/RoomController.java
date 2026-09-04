package com.pgplatform.owner.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.owner.RoomService;
import com.pgplatform.owner.dto.RoomCreateRequest;
import com.pgplatform.owner.dto.RoomResponse;
import com.pgplatform.owner.dto.RoomUpdateRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@PreAuthorize("hasRole('OWNER')")
public class RoomController {

    private final RoomService roomService;

    public RoomController(RoomService roomService) {
        this.roomService = roomService;
    }

    @PostMapping("/api/v1/owner/floors/{floorId}/rooms")
    public ResponseEntity<RoomResponse> create(@AuthenticationPrincipal UserPrincipal principal,
                                                @PathVariable UUID floorId,
                                                @Valid @RequestBody RoomCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(roomService.create(floorId, principal.getId(), request));
    }

    @GetMapping("/api/v1/owner/floors/{floorId}/rooms")
    public List<RoomResponse> list(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID floorId) {
        return roomService.listForFloor(floorId, principal.getId());
    }

    @PutMapping("/api/v1/owner/rooms/{roomId}")
    public RoomResponse update(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID roomId,
                                @Valid @RequestBody RoomUpdateRequest request) {
        return roomService.update(roomId, principal.getId(), request);
    }

    @DeleteMapping("/api/v1/owner/rooms/{roomId}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID roomId) {
        roomService.delete(roomId, principal.getId());
        return ResponseEntity.noContent().build();
    }
}
