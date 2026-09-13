package com.pgplatform.auth;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.dto.GoogleAuthRequest;
import com.pgplatform.auth.dto.OwnerLoginRequest;
import com.pgplatform.auth.dto.OwnerSignupRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

class StudentGoogleAuthFlowTest extends AbstractIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @MockBean
    private GoogleIdentityVerifier identityVerifier;

    @Test
    void googleCreatesAStudentAndReusesTheStableGoogleIdentity() {
        GoogleIdentity identity = new GoogleIdentity(
                "google-sub-new-student", "google.student@example.com", "Google Student");
        when(identityVerifier.verify("valid-student-token")).thenReturn(identity);

        ResponseEntity<AuthResponsePayload> first = restTemplate.postForEntity(
                "/api/v1/auth/student/google",
                new GoogleAuthRequest("valid-student-token"),
                AuthResponsePayload.class);
        ResponseEntity<AuthResponsePayload> second = restTemplate.postForEntity(
                "/api/v1/auth/student/google",
                new GoogleAuthRequest("valid-student-token"),
                AuthResponsePayload.class);

        assertThat(first.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(first.getBody()).isNotNull();
        assertThat(first.getBody().role()).isEqualTo("STUDENT");
        assertThat(first.getBody().fullName()).isEqualTo("Google Student");
        assertThat(second.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(second.getBody()).isNotNull();
        assertThat(second.getBody().userId()).isEqualTo(first.getBody().userId());

        User saved = userRepository.findByGoogleSubjectAndDeletedAtIsNull(identity.subject()).orElseThrow();
        assertThat(saved.getEmail()).isEqualTo(identity.email());
        assertThat(saved.getProvider()).isEqualTo(AuthProviderType.GOOGLE);
        assertThat(saved.isEmailVerified()).isTrue();
    }

    @Test
    void googleCannotConvertAnOwnerAndOwnerPasswordLoginStillWorks() {
        String email = "protected.owner@example.com";
        OwnerSignupRequest signup = new OwnerSignupRequest(
                "Protected Owner", email, "password123", null);
        ResponseEntity<AuthResponsePayload> ownerSignup = restTemplate.postForEntity(
                "/api/v1/auth/owner/signup", signup, AuthResponsePayload.class);
        assertThat(ownerSignup.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        when(identityVerifier.verify("owner-email-google-token")).thenReturn(
                new GoogleIdentity("google-sub-owner-email", email, "Protected Owner"));
        ResponseEntity<String> googleAttempt = restTemplate.postForEntity(
                "/api/v1/auth/student/google",
                new GoogleAuthRequest("owner-email-google-token"),
                String.class);
        assertThat(googleAttempt.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        ResponseEntity<AuthResponsePayload> ownerLogin = restTemplate.postForEntity(
                "/api/v1/auth/owner/login",
                new OwnerLoginRequest(email, "password123"),
                AuthResponsePayload.class);
        assertThat(ownerLogin.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(ownerLogin.getBody()).isNotNull();
        assertThat(ownerLogin.getBody().role()).isEqualTo("OWNER");

        User owner = userRepository.findByEmailAndDeletedAtIsNull(email).orElseThrow();
        assertThat(owner.getProvider()).isEqualTo(AuthProviderType.LOCAL);
        assertThat(owner.getGoogleSubject()).isNull();
    }

    record AuthResponsePayload(
            String accessToken,
            String refreshToken,
            UUID userId,
            String fullName,
            String role) {
    }
}
