package com.pgplatform.owner.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.owner.BedService;
import com.pgplatform.owner.dto.BedResponse;
import com.pgplatform.owner.dto.BedStatusUpdateRequest;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@PreAuthorize("hasRole('OWNER')")
public class BedController {

    private final BedService bedService;

    public BedController(BedService bedService) {
        this.bedService = bedService;
    }

    @GetMapping("/api/v1/owner/rooms/{roomId}/beds")
    public List<BedResponse> list(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID roomId) {
        return bedService.listForRoom(roomId, principal.getId());
    }

    @PatchMapping("/api/v1/owner/beds/{bedId}/status")
    public BedResponse updateStatus(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID bedId,
                                     @Valid @RequestBody BedStatusUpdateRequest request) {
        return bedService.updateStatus(bedId, principal.getId(), request);
    }
}
