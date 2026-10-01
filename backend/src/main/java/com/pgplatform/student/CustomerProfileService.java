package com.pgplatform.student;

import com.pgplatform.auth.OtpPurpose;
import com.pgplatform.auth.OtpService;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.booking.BookingType;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.document.DocumentStorageGateway;
import com.pgplatform.student.dto.BookingEligibilityResponse;
import com.pgplatform.student.dto.CustomerProfileResponse;
import com.pgplatform.student.dto.CustomerProfileUpdateRequest;
import com.pgplatform.student.dto.StudentPhoneOtpRequest;
import com.pgplatform.student.dto.StudentPhoneOtpVerifyRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class CustomerProfileService {
    private final CustomerProfileRepository profileRepository;
    private final LegalAcceptanceRepository acceptanceRepository;
    private final UserRepository userRepository;
    private final OtpService otpService;
    private final StudentRepository studentRepository;
    private final CustomerIdentityDocumentRepository identityDocumentRepository;
    private final DocumentStorageGateway storageGateway;

    @Value("${app.legal.terms-version:2026-09-22}")
    private String termsVersion;
    @Value("${app.legal.privacy-version:2026-09-22}")
    private String privacyVersion;
    @Value("${app.legal.aadhaar-consent-version:2026-09-22}")
    private String aadhaarConsentVersion;

    public CustomerProfileService(CustomerProfileRepository profileRepository,
                                  LegalAcceptanceRepository acceptanceRepository,
                                  UserRepository userRepository, OtpService otpService,
                                  StudentRepository studentRepository,
                                  CustomerIdentityDocumentRepository identityDocumentRepository,
                                  DocumentStorageGateway storageGateway) {
        this.profileRepository = profileRepository;
        this.acceptanceRepository = acceptanceRepository;
        this.userRepository = userRepository;
        this.otpService = otpService;
        this.studentRepository = studentRepository;
        this.identityDocumentRepository = identityDocumentRepository;
        this.storageGateway = storageGateway;
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
        profile.setContactPhone(normalizePhone(request.contactPhone()));
        profile.setPermanentAddress(trimToNull(request.permanentAddress()));
        profile.setGuardianName(trimToNull(request.guardianName()));
        profile.setGuardianPhone(normalizePhone(request.guardianPhone()));
        profile.setIdentityType(request.identityType());
        profile.setIdentityLastFour(null);
        profile = profileRepository.save(profile);

        if (!fullName.equals(user.getFullName())) {
            user.setFullName(fullName);
            userRepository.save(user);
        }
        studentRepository.findByUserIdAndDeletedAtIsNull(userId).ifPresent(student -> {
            applyToStudent(userId, student);
            studentRepository.save(student);
        });
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
        studentRepository.findByUserIdAndDeletedAtIsNull(userId).ifPresent(student -> {
            student.setPhone(request.phone());
            studentRepository.save(student);
        });
        return response(user, profileRepository.findByUserIdAndDeletedAtIsNull(userId).orElse(null));
    }

    @Transactional
    public CustomerProfileResponse uploadPhoto(UUID userId, byte[] content, String fileName, String contentType) {
        User user = requireStudentUser(userId);
        if (content == null || content.length == 0) throw new ConflictException("Choose a profile photo");
        if (content.length > 5L * 1024 * 1024) throw new ConflictException("Profile photo must be 5 MB or smaller");
        String normalizedType = contentType == null ? "" : contentType.toLowerCase();
        if (!normalizedType.equals("image/jpeg") && !normalizedType.equals("image/png")) {
            throw new ConflictException("Profile photo must be a JPG or PNG image");
        }
        CustomerProfile profile = profileRepository.findByUserIdAndDeletedAtIsNull(userId)
                .orElseGet(() -> {
                    CustomerProfile created = new CustomerProfile();
                    created.setUser(user);
                    created.setFullName(isBlank(user.getFullName()) ? "Student" : user.getFullName());
                    return created;
                });
        String oldKey = profile.getProfilePhotoStorageKey();
        String safeName = isBlank(fileName)
                ? "profile-photo" + (normalizedType.endsWith("png") ? ".png" : ".jpg")
                : fileName.trim();
        String newKey = storageGateway.store(content, safeName, normalizedType);
        profile.setProfilePhotoStorageKey(newKey);
        profile.setProfilePhotoFileName(safeName);
        profile.setProfilePhotoContentType(normalizedType);
        profile = profileRepository.save(profile);
        if (!isBlank(oldKey) && !oldKey.equals(newKey)) storageGateway.delete(oldKey);
        return response(user, profile);
    }

    @Transactional
    public CustomerProfileResponse deletePhoto(UUID userId) {
        User user = requireStudentUser(userId);
        CustomerProfile profile = profileRepository.findByUserIdAndDeletedAtIsNull(userId)
                .orElseThrow(() -> new NotFoundException("Customer profile not found"));
        String oldKey = profile.getProfilePhotoStorageKey();
        profile.setProfilePhotoStorageKey(null);
        profile.setProfilePhotoFileName(null);
        profile.setProfilePhotoContentType(null);
        profileRepository.save(profile);
        if (!isBlank(oldKey)) storageGateway.delete(oldKey);
        return response(user, profile);
    }

    private List<String> missingRequirements(User user, CustomerProfile profile, BookingType bookingType) {
        List<String> missing = new ArrayList<>();
        if (profile == null) {
            missing.add("PROFILE");
        }
        String name = profile == null ? user.getFullName() : profile.getFullName();
        if (isBlank(name) || "Student".equalsIgnoreCase(name.trim())) missing.add("FULL_NAME");
        if (profile == null || isBlank(profile.getOccupation())) missing.add("OCCUPATION");
        if (isBlank(effectiveContactPhone(user, profile))) missing.add("CONTACT_PHONE");
        if (!accepted(user.getId(), LegalDocumentType.TERMS, termsVersion)) missing.add("TERMS_ACCEPTANCE");
        if (!accepted(user.getId(), LegalDocumentType.PRIVACY, privacyVersion)) missing.add("PRIVACY_ACCEPTANCE");
        if (bookingType == BookingType.MONTHLY) {
            if (profile == null || isBlank(profile.getPermanentAddress())) missing.add("PERMANENT_ADDRESS");
            CustomerIdentityDocument document = profile == null ? null : identityDocumentRepository
                    .findByProfileIdAndDeletedAtIsNull(profile.getId()).orElse(null);
            if (profile == null || profile.getIdentityType() == null || document == null
                    || document.getIdentityType() != profile.getIdentityType()) {
                missing.add("IDENTITY");
            } else if (profile.getIdentityType() == IdentityType.AADHAAR
                    && !accepted(user.getId(), LegalDocumentType.AADHAAR_CONSENT, aadhaarConsentVersion)) {
                missing.add("AADHAAR_CONSENT");
            }
        }
        return List.copyOf(missing);
    }

    private void validateIdentity(CustomerProfileUpdateRequest request) {
        if (!isBlank(request.identityLast4())) {
            throw new ConflictException("ID numbers are not collected. Upload the document instead");
        }
        if (request.identityType() != null && request.identityType() != IdentityType.AADHAAR
                && request.identityType() != IdentityType.PASSPORT) {
            throw new ConflictException("Choose Aadhaar card or passport");
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
                profile == null ? null : profile.getOccupation(),
                profile == null || isBlank(profile.getProfilePhotoStorageKey()) ? null
                        : storageGateway.generateSignedUrl(profile.getProfilePhotoStorageKey(), Duration.ofMinutes(30)),
                effectiveContactPhone(user, profile),
                user.isPhoneVerified(),
                profile == null ? null : profile.getPermanentAddress(),
                profile == null ? null : profile.getGuardianName(),
                profile == null ? null : profile.getGuardianPhone(),
                profile == null ? null : profile.getIdentityType(),
                profile == null ? null : profile.getIdentityLastFour(),
                profile == null ? null : identityDocumentRepository
                        .findByProfileIdAndDeletedAtIsNull(profile.getId())
                        .map(com.pgplatform.student.dto.CustomerIdentityDocumentResponse::from).orElse(null),
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
    private static String normalizePhone(String value) {
        String phone = trimToNull(value);
        return phone == null ? null : phone.replaceAll("[\\s-]", "");
    }

    /** Copies customer-owned identity/contact details into the owner-visible stay record. */
    @Transactional(readOnly = true)
    public void applyToStudent(UUID userId, Student student) {
        User user = requireStudentUser(userId);
        CustomerProfile profile = profileRepository.findByUserIdAndDeletedAtIsNull(userId).orElse(null);
        student.setFullName(profile == null ? user.getFullName() : profile.getFullName());
        String contactPhone = effectiveContactPhone(user, profile);
        student.setPhone(contactPhone == null ? "" : contactPhone);
        student.setGuardianName(profile == null ? null : profile.getGuardianName());
        student.setGuardianPhone(profile == null ? null : profile.getGuardianPhone());
        student.setPermanentAddress(profile == null ? null : profile.getPermanentAddress());
    }

    private static String effectiveContactPhone(User user, CustomerProfile profile) {
        if (profile != null && !isBlank(profile.getContactPhone())) return profile.getContactPhone();
        return trimToNull(user.getPhone());
    }
    private static String limit(String value, int length) {
        if (isBlank(value)) return null;
        return value.length() <= length ? value : value.substring(0, length);
    }
}
