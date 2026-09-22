package com.pgplatform.student;

import com.pgplatform.auth.OtpPurpose;
import com.pgplatform.auth.OtpService;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.booking.BookingType;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.student.dto.BookingEligibilityResponse;
import com.pgplatform.student.dto.CustomerProfileResponse;
import com.pgplatform.student.dto.CustomerProfileUpdateRequest;
import com.pgplatform.student.dto.StudentPhoneOtpRequest;
import com.pgplatform.student.dto.StudentPhoneOtpVerifyRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Service
public class CustomerProfileService {
    private final CustomerProfileRepository profileRepository;
    private final LegalAcceptanceRepository acceptanceRepository;
    private final UserRepository userRepository;
    private final OtpService otpService;

    @Value("${app.legal.terms-version:2026-09-22}")
    private String termsVersion;
    @Value("${app.legal.privacy-version:2026-09-22}")
    private String privacyVersion;
    @Value("${app.legal.aadhaar-consent-version:2026-09-22}")
    private String aadhaarConsentVersion;

    public CustomerProfileService(CustomerProfileRepository profileRepository,
                                  LegalAcceptanceRepository acceptanceRepository,
                                  UserRepository userRepository, OtpService otpService) {
        this.profileRepository = profileRepository;
        this.acceptanceRepository = acceptanceRepository;
        this.userRepository = userRepository;
        this.otpService = otpService;
    }

    @Transactional(readOnly = true)
    public CustomerProfileResponse get(UUID userId) {
        User user = requireStudentUser(userId);
        CustomerProfile profile = profileRepository.findByUserIdAndDeletedAtIsNull(userId).orElse(null);
        return response(user, profile);
    }

    @Transactional
    public CustomerProfileResponse update(UUID userId, CustomerProfileUpdateRequest request,
                                          String ipAddress, String userAgent, String locale) {
        User user = requireStudentUser(userId);
        validateIdentity(request);
        CustomerProfile profile = profileRepository.findByUserIdAndDeletedAtIsNull(userId)
                .orElseGet(() -> {
                    CustomerProfile created = new CustomerProfile();
                    created.setUser(user);
                    return created;
                });
        String fullName = request.fullName().trim();
        profile.setFullName(fullName);
        profile.setOccupation(request.occupation().trim());
        profile.setPermanentAddress(trimToNull(request.permanentAddress()));
        profile.setIdentityType(request.identityType());
        profile.setIdentityLastFour(request.identityType() == null ? null
                : request.identityLast4().trim().toUpperCase(Locale.ROOT));
        profile = profileRepository.save(profile);

        if (!fullName.equals(user.getFullName())) {
            user.setFullName(fullName);
            userRepository.save(user);
        }
        if (request.acceptTerms()) {
            accept(user, LegalDocumentType.TERMS, termsVersion, ipAddress, userAgent, locale);
        }
        if (request.acceptPrivacy()) {
            accept(user, LegalDocumentType.PRIVACY, privacyVersion, ipAddress, userAgent, locale);
        }
        if (request.acceptAadhaarConsent()) {
            if (request.identityType() != IdentityType.AADHAAR) {
                throw new ConflictException("Aadhaar consent applies only when Aadhaar is voluntarily selected");
            }
            accept(user, LegalDocumentType.AADHAAR_CONSENT, aadhaarConsentVersion,
                    ipAddress, userAgent, locale);
        }
        return response(user, profile);
    }

    @Transactional(readOnly = true)
    public BookingEligibilityResponse eligibility(UUID userId, BookingType bookingType) {
        User user = requireStudentUser(userId);
        CustomerProfile profile = profileRepository.findByUserIdAndDeletedAtIsNull(userId).orElse(null);
        List<String> missing = missingRequirements(user, profile, bookingType);
        return new BookingEligibilityResponse(bookingType, missing.isEmpty(), missing);
    }

    @Transactional(readOnly = true)
    public void requireEligible(UUID userId, BookingType bookingType) {
        BookingEligibilityResponse result = eligibility(userId, bookingType);
        if (!result.eligible()) {
            throw new ConflictException("Complete your profile before booking. Missing: "
                    + String.join(", ", result.missingRequirements()));
        }
    }

    public void requestPhoneOtp(UUID userId, StudentPhoneOtpRequest request) {
        requireStudentUser(userId);
        userRepository.findByPhoneAndDeletedAtIsNull(request.phone())
                .filter(user -> !user.getId().equals(userId))
                .ifPresent(user -> { throw new ConflictException("This phone number is already in use"); });
        otpService.requestOtp(request.phone(), OtpPurpose.STUDENT_PHONE_VERIFICATION);
    }

    @Transactional
    public CustomerProfileResponse verifyPhoneOtp(UUID userId, StudentPhoneOtpVerifyRequest request) {
        User user = requireStudentUser(userId);
        if (!otpService.verifyOtp(request.phone(), request.code(), OtpPurpose.STUDENT_PHONE_VERIFICATION)) {
            throw new ConflictException("The OTP is invalid or expired");
        }
        userRepository.findByPhoneAndDeletedAtIsNull(request.phone())
                .filter(other -> !other.getId().equals(userId))
                .ifPresent(other -> { throw new ConflictException("This phone number is already in use"); });
        user.setPhone(request.phone());
        user.setPhoneVerified(true);
        userRepository.save(user);
        return response(user, profileRepository.findByUserIdAndDeletedAtIsNull(userId).orElse(null));
    }

    private List<String> missingRequirements(User user, CustomerProfile profile, BookingType bookingType) {
        List<String> missing = new ArrayList<>();
        if (profile == null) {
            missing.add("PROFILE");
        }
        String name = profile == null ? user.getFullName() : profile.getFullName();
        if (isBlank(name) || "Student".equalsIgnoreCase(name.trim())) missing.add("FULL_NAME");
        if (profile == null || isBlank(profile.getOccupation())) missing.add("OCCUPATION");
        if (!accepted(user.getId(), LegalDocumentType.TERMS, termsVersion)) missing.add("TERMS_ACCEPTANCE");
        if (!accepted(user.getId(), LegalDocumentType.PRIVACY, privacyVersion)) missing.add("PRIVACY_ACCEPTANCE");
        if (bookingType == BookingType.MONTHLY) {
            if (profile == null || isBlank(profile.getPermanentAddress())) missing.add("PERMANENT_ADDRESS");
            if (profile == null || profile.getIdentityType() == null || isBlank(profile.getIdentityLastFour())) {
                missing.add("IDENTITY");
            } else if (profile.getIdentityType() == IdentityType.AADHAAR
                    && !accepted(user.getId(), LegalDocumentType.AADHAAR_CONSENT, aadhaarConsentVersion)) {
                missing.add("AADHAAR_CONSENT");
            }
        }
        return List.copyOf(missing);
    }

    private void validateIdentity(CustomerProfileUpdateRequest request) {
        if (request.identityType() == null && !isBlank(request.identityLast4())) {
            throw new ConflictException("Select an identity type before entering its last four characters");
        }
        if (request.identityType() != null) {
            String lastFour = request.identityLast4();
            if (lastFour == null || !lastFour.matches("[A-Za-z0-9]{4}")) {
                throw new ConflictException("Identity reference must contain exactly the last four letters or digits");
            }
            if (request.identityType() == IdentityType.AADHAAR && !lastFour.matches("[0-9]{4}")) {
                throw new ConflictException("Aadhaar reference must contain only its last four digits");
            }
        }
    }

    private void accept(User user, LegalDocumentType type, String version,
                        String ipAddress, String userAgent, String locale) {
        if (accepted(user.getId(), type, version)) return;
        LegalAcceptance acceptance = new LegalAcceptance();
        acceptance.setUser(user);
        acceptance.setDocumentType(type);
        acceptance.setDocumentVersion(version);
        acceptance.setAcceptedAt(Instant.now());
        acceptance.setIpAddress(limit(ipAddress, 64));
        acceptance.setUserAgent(limit(userAgent, 500));
        acceptance.setLocale(limit(locale, 20));
        acceptanceRepository.save(acceptance);
    }

    private boolean accepted(UUID userId, LegalDocumentType type, String version) {
        return acceptanceRepository.existsByUserIdAndDocumentTypeAndDocumentVersionAndDeletedAtIsNull(
                userId, type, version);
    }

    private CustomerProfileResponse response(User user, CustomerProfile profile) {
        return new CustomerProfileResponse(
                profile == null ? null : profile.getId(),
                profile == null ? user.getFullName() : profile.getFullName(),
                profile == null ? null : profile.getOccupation(), user.getPhone(), user.isPhoneVerified(),
                profile == null ? null : profile.getPermanentAddress(),
                profile == null ? null : profile.getIdentityType(),
                profile == null ? null : profile.getIdentityLastFour(),
                latestVersion(user.getId(), LegalDocumentType.TERMS),
                latestVersion(user.getId(), LegalDocumentType.PRIVACY),
                latestVersion(user.getId(), LegalDocumentType.AADHAAR_CONSENT),
                profile == null ? null : profile.getUpdatedAt());
    }

    private String latestVersion(UUID userId, LegalDocumentType type) {
        return acceptanceRepository
                .findFirstByUserIdAndDocumentTypeAndDeletedAtIsNullOrderByAcceptedAtDesc(userId, type)
                .map(LegalAcceptance::getDocumentVersion).orElse(null);
    }

    private User requireStudentUser(UUID userId) {
        User user = userRepository.findByIdAndDeletedAtIsNull(userId)
                .orElseThrow(() -> new NotFoundException("Student account not found"));
        if (user.getRole() != Role.STUDENT) throw new ConflictException("Only students have customer profiles");
        return user;
    }

    private static boolean isBlank(String value) { return value == null || value.isBlank(); }
    private static String trimToNull(String value) { return isBlank(value) ? null : value.trim(); }
    private static String limit(String value, int length) {
        if (isBlank(value)) return null;
        return value.length() <= length ? value : value.substring(0, length);
    }
}
