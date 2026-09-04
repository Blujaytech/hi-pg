package com.pgplatform.auth;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.dto.OwnerLoginRequest;
import com.pgplatform.auth.dto.OwnerSignupRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;

class OwnerAuthFlowTest extends AbstractIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void ownerCanSignUpThenLoginWithTheSameCredentials() {
        OwnerSignupRequest signup = new OwnerSignupRequest("Asha Rao", "asha@example.com", "password123", "9999999999");

        ResponseEntity<AuthResponsePayload> signupResponse =
                restTemplate.postForEntity("/api/v1/auth/owner/signup", signup, AuthResponsePayload.class);

        assertThat(signupResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(signupResponse.getBody()).isNotNull();
        assertThat(signupResponse.getBody().role()).isEqualTo("OWNER");

        OwnerLoginRequest login = new OwnerLoginRequest("asha@example.com", "password123");
        ResponseEntity<AuthResponsePayload> loginResponse =
                restTemplate.postForEntity("/api/v1/auth/owner/login", login, AuthResponsePayload.class);

        assertThat(loginResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(loginResponse.getBody()).isNotNull();
        assertThat(loginResponse.getBody().accessToken()).isNotBlank();
    }

    @Test
    void ownerSignupRejectsDuplicateEmail() {
        OwnerSignupRequest signup = new OwnerSignupRequest("Second Try", "dup@example.com", "password123", null);
        restTemplate.postForEntity("/api/v1/auth/owner/signup", signup, AuthResponsePayload.class);

        ResponseEntity<String> secondAttempt =
                restTemplate.postForEntity("/api/v1/auth/owner/signup", signup, String.class);

        assertThat(secondAttempt.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    record AuthResponsePayload(String accessToken, String refreshToken, String userId, String fullName, String role) {
    }
}
