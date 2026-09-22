package com.pgplatform.owner.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.owner.DirectPaymentSettingsService;
import com.pgplatform.owner.dto.DirectPaymentSettingsResponse;
import com.pgplatform.owner.dto.DirectPaymentSettingsUpdateRequest;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/owner/pgs/{pgId}/direct-payment-settings")
@PreAuthorize("hasRole('OWNER')")
public class OwnerDirectPaymentSettingsController {
    private final DirectPaymentSettingsService service;

    public OwnerDirectPaymentSettingsController(DirectPaymentSettingsService service) {
        this.service = service;
    }

    @GetMapping
    public DirectPaymentSettingsResponse get(@AuthenticationPrincipal UserPrincipal principal,
                                             @PathVariable UUID pgId) {
        return service.get(pgId, principal.getId());
    }

    @PutMapping
    public DirectPaymentSettingsResponse update(@AuthenticationPrincipal UserPrincipal principal,
                                                @PathVariable UUID pgId,
                                                @Valid @RequestBody DirectPaymentSettingsUpdateRequest request) {
        return service.update(pgId, principal.getId(), request);
    }
}
