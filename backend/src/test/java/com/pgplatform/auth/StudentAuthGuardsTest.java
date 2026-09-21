package com.pgplatform.auth;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.dto.StudentOtpVerifyRequest;
import com.pgplatform.common.ConflictException;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.BadCredentialsException;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * The phone/OTP login path used to skip both guards its sibling (GoogleAuthService)
 * applies: it issued a token carrying whatever role the phone's account held -- so an
 * owner or admin session could be obtained through the student endpoint -- and it kept
 * working for accounts an admin had disabled.
 */
class StudentAuthGuardsTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private OtpCodeRepository otpCodeRepository;
    @Autowired
    private StudentAuthService studentAuthService;
    @Autowired
    private SessionService sessionService;
    @Autowired
    private JwtService jwtService;

    private static final String KNOWN_CODE = "123456";

    /**
     * Seeds the same row OtpService.requestOtp would write, with a code we already know --
     * the real code is only ever delivered over SMS, and these tests are about what
     * happens *after* a correct OTP, not about OTP issuing itself.
     */
    private String issueOtp(String phone) {
        OtpCode otp = new OtpCode();
        otp.setPhone(phone);
        otp.setPurpose(OtpPurpose.STUDENT_SIGNUP_OR_LOGIN);
        otp.setCodeHash(jwtService.hash(KNOWN_CODE));
        otp.setExpiresAt(Instant.now().plus(5, ChronoUnit.MINUTES));
        otpCodeRepository.save(otp);
        return KNOWN_CODE;
    }

    private User saveUser(String phone, Role role, UserStatus status) {
        User user = new User();
        user.setPhone(phone);
        user.setFullName("Person " + phone);
        user.setRole(role);
        user.setProvider(AuthProviderType.LOCAL);
        user.setPhoneVerified(true);
        user.setStatus(status);
        if (role != Role.STUDENT) {
            user.setEmail("user-" + UUID.randomUUID() + "@example.com");
        }
        return userRepository.save(user);
    }

    @Test
    void theStudentOtpEndpointWillNotIssueASessionForAnOwnerAccount() {
        String phone = "9700000001";
        saveUser(phone, Role.OWNER, UserStatus.ACTIVE);
        String code = issueOtp(phone);

        assertThatThrownBy(() -> studentAuthService.verifyOtp(new StudentOtpVerifyRequest(phone, code, null)))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void aDisabledStudentCannotLogBackInWithAValidOtp() {
        String phone = "9700000002";
        saveUser(phone, Role.STUDENT, UserStatus.DISABLED);
        String code = issueOtp(phone);

        assertThatThrownBy(() -> studentAuthService.verifyOtp(new StudentOtpVerifyRequest(phone, code, null)))
                .isInstanceOf(BadCredentialsException.class);
    }

    @Test
    void disablingAnAccountAlsoStopsItsRefreshTokenFromMintingNewSessions() {
        String phone = "9700000003";
        User student = saveUser(phone, Role.STUDENT, UserStatus.ACTIVE);
        String refreshToken = studentAuthService
                .verifyOtp(new StudentOtpVerifyRequest(phone, issueOtp(phone), null))
                .refreshToken();

        // Refresh works while the account is in good standing.
        String rotated = sessionService.refresh(refreshToken).refreshToken();
        assertThat(rotated).isNotBlank();

        student.setStatus(UserStatus.DISABLED);
        userRepository.save(student);

        assertThatThrownBy(() -> sessionService.refresh(rotated))
                .isInstanceOf(BadCredentialsException.class);
    }
}
