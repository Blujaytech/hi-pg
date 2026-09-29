package com.pgplatform.auth;

import com.pgplatform.auth.dto.AuthResponse;
import com.pgplatform.common.ConflictException;
import com.pgplatform.owner.PgClaimService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OwnerFirebasePhoneAuthServiceTest {

    @Mock private UserRepository userRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private TokenIssuer tokenIssuer;
    @Mock private FirebasePhoneIdentityVerifier firebaseIdentityVerifier;
    @Mock private PgClaimService pgClaimService;

    private OwnerAuthService service;

    @BeforeEach
    void setUp() {
        service = new OwnerAuthService(userRepository, passwordEncoder, tokenIssuer,
                firebaseIdentityVerifier, pgClaimService);
    }

    @Test
    void invitedVerifiedMobileCreatesAnOwnerAccount() {
        String phone = "+919652297185";
        AuthResponse issued = new AuthResponse("access", "refresh", UUID.randomUUID(), "Nazeer", Role.OWNER);
        when(firebaseIdentityVerifier.verify("firebase-token"))
                .thenReturn(new FirebasePhoneIdentity("firebase-uid", phone));
        when(userRepository.findByPhoneAndDeletedAtIsNull(phone)).thenReturn(Optional.empty());
        when(userRepository.findByPhoneAndDeletedAtIsNull("9652297185")).thenReturn(Optional.empty());
        when(pgClaimService.hasInvitation(phone)).thenReturn(true);
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(tokenIssuer.issueFor(any(User.class))).thenReturn(issued);

        AuthResponse response = service.authenticateFirebasePhone("firebase-token", "Nazeer Basha");

        assertThat(response).isSameAs(issued);
        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(saved.capture());
        assertThat(saved.getValue().getRole()).isEqualTo(Role.OWNER);
        assertThat(saved.getValue().getPhone()).isEqualTo(phone);
        assertThat(saved.getValue().isPhoneVerified()).isTrue();
        assertThat(saved.getValue().getFullName()).isEqualTo("Nazeer Basha");
    }

    @Test
    void unknownMobileCannotCreateAnOwnerAccount() {
        String phone = "+919000000001";
        when(firebaseIdentityVerifier.verify("firebase-token"))
                .thenReturn(new FirebasePhoneIdentity("firebase-uid", phone));
        when(userRepository.findByPhoneAndDeletedAtIsNull(phone)).thenReturn(Optional.empty());
        when(userRepository.findByPhoneAndDeletedAtIsNull("9000000001")).thenReturn(Optional.empty());
        when(pgClaimService.hasInvitation(phone)).thenReturn(false);

        assertThatThrownBy(() -> service.authenticateFirebasePhone("firebase-token", null))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("No PG invitation");
        verify(userRepository, never()).save(any());
        verify(tokenIssuer, never()).issueFor(any());
    }

    @Test
    void customerMobileCannotBeConvertedIntoAnOwner() {
        String phone = "+919000000002";
        User customer = new User();
        customer.setRole(Role.STUDENT);
        customer.setPhone(phone);
        customer.setPhoneVerified(true);
        customer.setFullName("Customer");
        when(firebaseIdentityVerifier.verify("firebase-token"))
                .thenReturn(new FirebasePhoneIdentity("firebase-uid", phone));
        when(userRepository.findByPhoneAndDeletedAtIsNull(phone)).thenReturn(Optional.of(customer));

        assertThatThrownBy(() -> service.authenticateFirebasePhone("firebase-token", "Customer"))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("customer account");
        verify(userRepository, never()).save(any());
        verify(tokenIssuer, never()).issueFor(any());
    }
}
