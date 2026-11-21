package com.pgplatform.auth;

import com.pgplatform.auth.dto.FirebasePhoneVerificationRequest;
import com.pgplatform.common.ConflictException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OwnerPhoneVerificationServiceTest {

    @Mock private UserRepository userRepository;
    @Mock private OtpService otpService;
    @Mock private FirebasePhoneIdentityVerifier firebaseIdentityVerifier;

    private OwnerPhoneVerificationService service;

    @BeforeEach
    void setUp() {
        service = new OwnerPhoneVerificationService(userRepository, otpService, firebaseIdentityVerifier);
    }

    @Test
    void firebaseVerifiedPhoneUpdatesOwnerProfile() {
        UUID ownerId = UUID.randomUUID();
        User owner = owner(ownerId);
        when(userRepository.findByIdAndDeletedAtIsNull(ownerId)).thenReturn(Optional.of(owner));
        when(firebaseIdentityVerifier.verify("firebase-token"))
                .thenReturn(new FirebasePhoneIdentity("firebase-uid", "+91 96522 97185"));
        when(userRepository.findByPhoneAndDeletedAtIsNull("+919652297185")).thenReturn(Optional.empty());

        service.verifyFirebase(ownerId, new FirebasePhoneVerificationRequest("firebase-token"));

        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(saved.capture());
        assertThat(saved.getValue().getPhone()).isEqualTo("+919652297185");
        assertThat(saved.getValue().isPhoneVerified()).isTrue();
        assertThat(saved.getValue().getFirebaseSubject()).isEqualTo("firebase-uid");
    }

    @Test
    void firebaseVerifiedPhoneCannotReplaceAnotherUsersPhone() {
        UUID ownerId = UUID.randomUUID();
        User owner = owner(ownerId);
        User existing = owner(UUID.randomUUID());
        existing.setPhone("+919652297185");
        when(userRepository.findByIdAndDeletedAtIsNull(ownerId)).thenReturn(Optional.of(owner));
        when(firebaseIdentityVerifier.verify("firebase-token"))
                .thenReturn(new FirebasePhoneIdentity("firebase-uid", "+919652297185"));
        when(userRepository.findByPhoneAndDeletedAtIsNull("+919652297185"))
                .thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> service.verifyFirebase(
                ownerId, new FirebasePhoneVerificationRequest("firebase-token")))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("already in use");
        verify(userRepository, never()).save(owner);
    }

    private User owner(UUID id) {
        User user = new User();
        user.setId(id);
        user.setRole(Role.OWNER);
        user.setFullName("Owner");
        return user;
    }
}
