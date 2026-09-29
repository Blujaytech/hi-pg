package com.pgplatform.owner;

import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.common.ConflictException;
import com.pgplatform.notification.NotificationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PgClaimServiceTest {

    @Mock private PgRepository pgRepository;
    @Mock private PgOwnerContactRepository contactRepository;
    @Mock private PgClaimRequestRepository claimRepository;
    @Mock private PgInterestRequestRepository interestRepository;
    @Mock private UserRepository userRepository;
    @Mock private NotificationService notificationService;

    private PgClaimService service;

    @BeforeEach
    void setUp() {
        service = new PgClaimService(pgRepository, contactRepository, claimRepository,
                interestRepository, userRepository, notificationService);
    }

    @Test
    void matchingVerifiedMobileCanClaimButCannotEnableBooking() {
        UUID ownerId = UUID.randomUUID();
        UUID pgId = UUID.randomUUID();
        User owner = user(ownerId, Role.OWNER, "+919652297185");
        owner.setPhoneVerified(true);
        Pg pg = new Pg();
        pg.setId(pgId);
        pg.setName("Ameerpet Stay");
        pg.setClaimStatus(PgClaimStatus.UNCLAIMED);
        PgOwnerContact contact = new PgOwnerContact();
        contact.setPg(pg);
        contact.setNormalizedMobile("+919652297185");

        when(userRepository.findByIdAndDeletedAtIsNull(ownerId)).thenReturn(Optional.of(owner));
        when(pgRepository.findLockedByIdAndDeletedAtIsNull(pgId)).thenReturn(Optional.of(pg));
        when(contactRepository.findByPgIdAndDeletedAtIsNull(pgId)).thenReturn(Optional.of(contact));
        when(claimRepository.findByPgIdAndStatusAndDeletedAtIsNull(
                pgId, PgClaimRequestStatus.PENDING)).thenReturn(Optional.empty());
        when(claimRepository.findByPgIdAndClaimantIdAndDeletedAtIsNull(pgId, ownerId))
                .thenReturn(Optional.empty());
        when(interestRepository.countByPgIdAndDeletedAtIsNull(pgId)).thenReturn(3L);

        var response = service.claim(pgId, ownerId);

        assertThat(pg.getOwner()).isSameAs(owner);
        assertThat(pg.getClaimStatus()).isEqualTo(PgClaimStatus.CLAIM_PENDING);
        assertThat(pg.getVerificationStatus()).isEqualTo(PgVerificationStatus.UNVERIFIED);
        assertThat(pg.isBookingEnabled()).isFalse();
        assertThat(contact.getInvitationStatus()).isEqualTo(PgInvitationStatus.CLAIMED);
        assertThat(response.interestCount()).isEqualTo(3L);
        verify(claimRepository).save(any(PgClaimRequest.class));
    }

    @Test
    void interestOnUnclaimedPgIsRecordedWithoutPretendingPushWasDelivered() {
        UUID customerId = UUID.randomUUID();
        UUID pgId = UUID.randomUUID();
        User customer = user(customerId, Role.STUDENT, "+919111111111");
        Pg pg = new Pg();
        pg.setId(pgId);
        pg.setName("Ameerpet Stay");

        when(userRepository.findByIdAndDeletedAtIsNull(customerId)).thenReturn(Optional.of(customer));
        when(pgRepository.findLockedByIdAndDeletedAtIsNull(pgId))
                .thenReturn(Optional.of(pg));
        when(interestRepository.findByPgIdAndCustomerIdAndDeletedAtIsNull(pgId, customerId))
                .thenReturn(Optional.empty());
        when(interestRepository.save(any(PgInterestRequest.class))).thenAnswer(invocation -> {
            PgInterestRequest interest = invocation.getArgument(0);
            interest.setId(UUID.randomUUID());
            return interest;
        });
        when(interestRepository.countByPgIdAndDeletedAtIsNull(pgId)).thenReturn(1L);

        var response = service.registerInterest(pgId, customerId);

        assertThat(response.registered()).isTrue();
        assertThat(response.interestCount()).isEqualTo(1L);
        verify(notificationService, never()).notifyUser(any(), any(), any());
    }

    @Test
    void verifiedBookablePgDoesNotAcceptVerificationInterest() {
        UUID customerId = UUID.randomUUID();
        UUID pgId = UUID.randomUUID();
        User customer = user(customerId, Role.STUDENT, "+919111111111");
        Pg pg = new Pg();
        pg.setId(pgId);
        pg.setStatus(PgStatus.ACTIVE);
        pg.setVerificationStatus(PgVerificationStatus.VERIFIED);
        pg.setBookingEnabled(true);

        when(userRepository.findByIdAndDeletedAtIsNull(customerId)).thenReturn(Optional.of(customer));
        when(pgRepository.findLockedByIdAndDeletedAtIsNull(pgId)).thenReturn(Optional.of(pg));

        assertThatThrownBy(() -> service.registerInterest(pgId, customerId))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("already verified");
        verify(interestRepository, never()).save(any());
    }

    private User user(UUID id, Role role, String phone) {
        User user = new User();
        user.setId(id);
        user.setRole(role);
        user.setPhone(phone);
        return user;
    }
}
