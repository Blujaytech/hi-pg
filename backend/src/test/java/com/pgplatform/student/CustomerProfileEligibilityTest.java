package com.pgplatform.student;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.booking.BookingType;
import com.pgplatform.common.ConflictException;
import com.pgplatform.student.dto.CustomerProfileUpdateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class CustomerProfileEligibilityTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private CustomerProfileService profileService;

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
                IdentityType.VOTER_ID, "A1B2", false, false, false),
                "127.0.0.1", "test", "en-IN");

        assertThat(profileService.eligibility(user.getId(), BookingType.MONTHLY).eligible()).isTrue();
    }

    @Test
    void aadhaarAcceptsOnlyLastFourDigitsAndRequiresSeparateConsent() {
        User user = student("Customer Two", "9000000012", true);

        assertThatThrownBy(() -> profileService.update(user.getId(),
                new CustomerProfileUpdateRequest("Customer Two", "Engineer", "Address",
                        IdentityType.AADHAAR, "123456789012", true, true, true),
                null, null, null)).isInstanceOf(ConflictException.class);

        profileService.update(user.getId(), new CustomerProfileUpdateRequest(
                "Customer Two", "Engineer", "45 Monthly Address",
                IdentityType.AADHAAR, "9012", true, true, false),
                null, null, null);

        assertThat(profileService.eligibility(user.getId(), BookingType.MONTHLY)
                .missingRequirements()).containsExactly("AADHAAR_CONSENT");

        profileService.update(user.getId(), new CustomerProfileUpdateRequest(
                "Customer Two", "Engineer", "45 Monthly Address",
                IdentityType.AADHAAR, "9012", false, false, true),
                null, null, null);
        assertThat(profileService.eligibility(user.getId(), BookingType.MONTHLY).eligible()).isTrue();
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
