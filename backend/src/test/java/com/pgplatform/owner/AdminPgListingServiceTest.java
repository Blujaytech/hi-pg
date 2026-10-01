package com.pgplatform.owner;

import com.pgplatform.owner.dto.AdminPgListingRequest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminPgListingServiceTest {

    @Mock private PgRepository pgRepository;
    @Mock private PgOwnerContactRepository contactRepository;
    @Mock private PgInterestRequestRepository interestRepository;
    @Mock private OwnerSmsService smsService;

    @Test
    void adminListingStartsUnclaimedUnverifiedAndNotBookable() {
        when(pgRepository.save(any(Pg.class))).thenAnswer(invocation -> {
            Pg pg = invocation.getArgument(0);
            pg.setId(UUID.randomUUID());
            return pg;
        });
        when(contactRepository.save(any(PgOwnerContact.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
        when(smsService.sendOnce(any(Pg.class), any(), any(), any()))
                .thenReturn(new OwnerSmsResult(OwnerSmsStatus.SKIPPED, null, "SMS disabled in test"));

        AdminPgListingService service = new AdminPgListingService(
                pgRepository, contactRepository, interestRepository, smsService);
        var response = service.create(new AdminPgListingRequest(
                "Ameerpet Stay", "Owner Name", "96522 97185",
                "Yellareddyguda, Ameerpet", "Hyderabad", "Telangana", "500038",
                17.4374, 78.4482, "Admin-curated listing", GenderPreference.MALE));

        ArgumentCaptor<Pg> pgCaptor = ArgumentCaptor.forClass(Pg.class);
        verify(pgRepository).save(pgCaptor.capture());
        Pg saved = pgCaptor.getValue();
        assertThat(saved.getOwner()).isNull();
        assertThat(saved.isAdminCreated()).isTrue();
        assertThat(saved.getClaimStatus()).isEqualTo(PgClaimStatus.UNCLAIMED);
        assertThat(saved.getVerificationStatus()).isEqualTo(PgVerificationStatus.UNVERIFIED);
        assertThat(saved.isBookingEnabled()).isFalse();

        ArgumentCaptor<PgOwnerContact> contactCaptor = ArgumentCaptor.forClass(PgOwnerContact.class);
        verify(contactRepository).save(contactCaptor.capture());
        assertThat(contactCaptor.getValue().getNormalizedMobile()).isEqualTo("+919652297185");
        assertThat(contactCaptor.getValue().getInvitationStatus())
                .isEqualTo(PgInvitationStatus.PENDING_PROVIDER);
        assertThat(response.bookingEnabled()).isFalse();
        assertThat(response.ownerMobile()).isEqualTo("+919652297185");
    }
}
