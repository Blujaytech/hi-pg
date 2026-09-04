package com.pgplatform.owner.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.owner.FloorService;
import com.pgplatform.owner.dto.FloorCreateRequest;
import com.pgplatform.owner.dto.FloorResponse;
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
public class FloorController {

    private final FloorService floorService;

    public FloorController(FloorService floorService) {
        this.floorService = floorService;
    }

    @PostMapping("/api/v1/owner/pgs/{pgId}/floors")
    public ResponseEntity<FloorResponse> create(@AuthenticationPrincipal UserPrincipal principal,
                                                 @PathVariable UUID pgId,
                                                 @Valid @RequestBody FloorCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(floorService.create(pgId, principal.getId(), request));
    }

    @GetMapping("/api/v1/owner/pgs/{pgId}/floors")
    public List<FloorResponse> list(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        return floorService.listForPg(pgId, principal.getId());
    }

    @PutMapping("/api/v1/owner/floors/{floorId}")
    public FloorResponse update(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID floorId,
                                 @Valid @RequestBody FloorCreateRequest request) {
        return floorService.update(floorId, principal.getId(), request);
    }

    @DeleteMapping("/api/v1/owner/floors/{floorId}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID floorId) {
        floorService.delete(floorId, principal.getId());
        return ResponseEntity.noContent().build();
    }
}
