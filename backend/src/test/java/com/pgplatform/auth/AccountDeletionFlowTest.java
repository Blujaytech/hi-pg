package com.pgplatform.auth;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.dto.AuthResponse;
import com.pgplatform.auth.dto.OwnerLoginRequest;
import com.pgplatform.auth.dto.OwnerSignupRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class AccountDeletionFlowTest extends AbstractIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;
    @Autowired
    private UserRepository userRepository;
    @Autowired
    private TokenIssuer tokenIssuer;

    @Test
    void ownerDeletionRevokesLoginAndAnonymizesIdentifiers() {
        AuthPayload session = signupOwner("delete-owner@example.com", "password123");

        ResponseEntity<Void> response = delete(session.accessToken(), "DELETE", "password123");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(userRepository.findByIdAndDeletedAtIsNull(UUID.fromString(session.userId()))).isEmpty();
        Map<String, Object> row = jdbcTemplate.queryForMap(
                "select email, phone, full_name, password_hash, status, deleted_at from users where id = ?",
                UUID.fromString(session.userId()));
        assertThat(row.get("email").toString()).startsWith("deleted+");
        assertThat(row.get("phone")).isNull();
        assertThat(row.get("full_name")).isEqualTo("Deleted user");
        assertThat(row.get("password_hash")).isNull();
        assertThat(row.get("status")).isEqualTo("DISABLED");
        assertThat(row.get("deleted_at")).isNotNull();
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from account_deletion_audits where account_id = ?",
                Long.class, UUID.fromString(session.userId()))).isEqualTo(1L);

        ResponseEntity<String> login = restTemplate.postForEntity(
                "/api/v1/auth/owner/login",
                new OwnerLoginRequest("delete-owner@example.com", "password123"), String.class);
        assertThat(login.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void ownerDeletionRequiresTheCurrentPassword() {
        AuthPayload session = signupOwner("keep-owner@example.com", "password123");

        ResponseEntity<Void> response = delete(session.accessToken(), "DELETE", "wrong-password");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(userRepository.findByIdAndDeletedAtIsNull(UUID.fromString(session.userId()))).isPresent();
    }

    @Test
    void phoneCustomerCanDeleteWithoutAnOwnerPassword() {
        User customer = new User();
        customer.setPhone("+919999000001");
        customer.setFullName("Delete Customer");
        customer.setRole(Role.STUDENT);
        customer.setProvider(AuthProviderType.LOCAL);
        customer.setPhoneVerified(true);
        customer = userRepository.save(customer);
        AuthResponse session = tokenIssuer.issueFor(customer);

        ResponseEntity<Void> response = delete(session.accessToken(), "DELETE", null);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(userRepository.findByIdAndDeletedAtIsNull(customer.getId())).isEmpty();
    }

    @Test
    void administratorsCannotSelfDeleteThroughTheConsumerFlow() {
        User admin = new User();
        admin.setEmail("protected-admin@example.com");
        admin.setFullName("Protected Admin");
        admin.setRole(Role.ADMIN);
        admin.setProvider(AuthProviderType.LOCAL);
        admin = userRepository.save(admin);
        AuthResponse session = tokenIssuer.issueFor(admin);

        ResponseEntity<Void> response = delete(session.accessToken(), "DELETE", null);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(userRepository.findByIdAndDeletedAtIsNull(admin.getId())).isPresent();
    }

    private AuthPayload signupOwner(String email, String password) {
        ResponseEntity<AuthPayload> response = restTemplate.postForEntity(
                "/api/v1/auth/owner/signup",
                new OwnerSignupRequest("Deletion Owner", email, password, null), AuthPayload.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return response.getBody();
    }

    private ResponseEntity<Void> delete(String accessToken, String confirmation, String password) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        return restTemplate.exchange(
                "/api/v1/me/account-deletion",
                HttpMethod.POST,
                new HttpEntity<>(Map.of(
                        "confirmation", confirmation,
                        "currentPassword", password == null ? "" : password
                ), headers),
                Void.class);
    }

    record AuthPayload(String accessToken, String refreshToken, String userId, String fullName, String role) {
    }
}
