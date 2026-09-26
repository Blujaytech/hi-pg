package com.pgplatform.student;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.auth.JwtService;
import com.pgplatform.booking.BookingType;
import com.pgplatform.common.ConflictException;
import com.pgplatform.student.dto.BookingEligibilityResponse;
import com.pgplatform.student.dto.CustomerProfileUpdateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class CustomerProfileEligibilityTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private CustomerProfileService profileService;
    @Autowired
    private TestRestTemplate restTemplate;
    @Autowired
    private JwtService jwtService;

    @Test
    void dayWiseNeedsOnlyBasicProfileWhileMonthlyNeedsAddressAndIdentity() {
        User user = student("Customer One", "9000000011", true);

        profileService.update(user.getId(), new CustomerProfileUpdateRequest(
                "Customer One", "Student", null, null, null,
                true, true, false), "127.0.0.1", "test", "en-IN");

        assertThat(profileService.eligibility(user.getId(), BookingType.DAY_WISE).eligible()).isTrue();
        var monthly = profileService.eligibility(user.getId(), BookingType.MONTHLY);
        assertThat(monthly.eligible()).isFalse();
        assertThat(monthly.missingRequirements()).containsExactly("PERMANENT_ADDRESS", "IDENTITY");

        profileService.update(user.getId(), new CustomerProfileUpdateRequest(
                "Customer One", "Student", "12 Test Road, Bengaluru",
                IdentityType.PASSPORT, null, false, false, false),
                "127.0.0.1", "test", "en-IN");

        assertThat(profileService.eligibility(user.getId(), BookingType.MONTHLY).eligible()).isFalse();
        addIdentityDocument(user.getId(), "PASSPORT");
        assertThat(profileService.eligibility(user.getId(), BookingType.MONTHLY).eligible()).isTrue();
    }

    @Test
    void bookingDoesNotRequireAVerifiedMobile() {
        User user = student("Customer Three", "9000000013", false);

        profileService.update(user.getId(), new CustomerProfileUpdateRequest(
                "Customer Three", "Student", null, null, null,
                true, true, false), "127.0.0.1", "test", "en-IN");

        assertThat(profileService.eligibility(user.getId(), BookingType.DAY_WISE).eligible()).isTrue();
    }

    @Test
    void monthlyEligibilityEndpointAcceptsTheMobileContract() {
        User user = student("Google Customer", "9000000014", false);
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(jwtService.generateAccessToken(user));

        ResponseEntity<BookingEligibilityResponse> response = restTemplate.exchange(
                "/api/v1/student/profile/booking-eligibility?bookingType=MONTHLY",
                HttpMethod.GET,
                new HttpEntity<>(headers),
                BookingEligibilityResponse.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().bookingType()).isEqualTo(BookingType.MONTHLY);
        assertThat(response.getBody().eligible()).isFalse();
        assertThat(response.getBody().missingRequirements())
                .contains("PROFILE", "OCCUPATION",
                        "TERMS_ACCEPTANCE", "PRIVACY_ACCEPTANCE",
                        "PERMANENT_ADDRESS", "IDENTITY");
    }

    @Test
    void aadhaarRequiresUploadedDocumentAndSeparateConsent() {
        User user = student("Customer Two", "9000000012", true);

        assertThatThrownBy(() -> profileService.update(user.getId(),
                new CustomerProfileUpdateRequest("Customer Two", "Engineer", "Address",
                        IdentityType.VOTER_ID, null, true, true, false),
                null, null, null)).isInstanceOf(ConflictException.class);

        profileService.update(user.getId(), new CustomerProfileUpdateRequest(
                "Customer Two", "Engineer", "45 Monthly Address",
                IdentityType.AADHAAR, null, true, true, false),
                null, null, null);

        assertThat(profileService.eligibility(user.getId(), BookingType.MONTHLY)
                .missingRequirements()).containsExactly("IDENTITY");

        addIdentityDocument(user.getId(), "AADHAAR");
        assertThat(profileService.eligibility(user.getId(), BookingType.MONTHLY)
                .missingRequirements()).containsExactly("AADHAAR_CONSENT");

        profileService.update(user.getId(), new CustomerProfileUpdateRequest(
                "Customer Two", "Engineer", "45 Monthly Address",
                IdentityType.AADHAAR, null, false, false, true),
                null, null, null);
        assertThat(profileService.eligibility(user.getId(), BookingType.MONTHLY).eligible()).isTrue();
    }

    private void addIdentityDocument(UUID userId, String identityType) {
        UUID profileId = jdbcTemplate.queryForObject(
                "select id from customer_profiles where user_id = ?", UUID.class, userId);
        jdbcTemplate.update("""
                insert into customer_identity_documents
                    (id, profile_id, identity_type, file_name, content_type,
                     size_bytes, storage_key, created_at, updated_at)
                values (?, ?, ?, 'identity.pdf', 'application/pdf', 5, ?, now(), now())
                """, UUID.randomUUID(), profileId, identityType,
                "private/test/" + UUID.randomUUID() + "/identity.pdf");
    }

    private User student(String name, String phone, boolean phoneVerified) {
        User user = new User();
        user.setFullName(name);
        user.setPhone(phone);
        user.setPhoneVerified(phoneVerified);
        user.setRole(Role.STUDENT);
        user.setProvider(AuthProviderType.LOCAL);
        return userRepository.save(user);
    }
}
