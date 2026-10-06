package com.pgplatform.auth;

import com.google.firebase.auth.AuthErrorCode;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.pgplatform.auth.dto.AccountDeletionRequest;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.payment.RazorpayGateway;
import com.pgplatform.payment.RazorpayProperties;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Irreversibly removes login/profile data while retaining only the anonymous
 * booking, payment and statutory records required to reconcile past business.
 */
@Service
public class AccountDeletionService {

    public static final String RETENTION_POLICY_VERSION = "2026-10-02";
    static final String RETAINED_DATA_SUMMARY =
            "Anonymized booking, payment, receipt, tax, fraud-prevention and legal acceptance records";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JdbcTemplate jdbcTemplate;
    private final RazorpayGateway razorpayGateway;
    private final RazorpayProperties razorpayProperties;
    private final ObjectProvider<FirebaseAuth> firebaseAuth;

    public AccountDeletionService(UserRepository userRepository, PasswordEncoder passwordEncoder,
                                  JdbcTemplate jdbcTemplate, RazorpayGateway razorpayGateway,
                                  RazorpayProperties razorpayProperties,
                                  ObjectProvider<FirebaseAuth> firebaseAuth) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jdbcTemplate = jdbcTemplate;
        this.razorpayGateway = razorpayGateway;
        this.razorpayProperties = razorpayProperties;
        this.firebaseAuth = firebaseAuth;
    }

    @Transactional
    public UUID deleteCurrentAccount(UUID userId, AccountDeletionRequest request) {
        if (!"DELETE".equals(request.confirmation())) {
            throw new IllegalArgumentException("Type DELETE exactly to confirm account deletion");
        }

        User user = userRepository.findLockedByIdAndDeletedAtIsNull(userId)
                .orElseThrow(() -> new NotFoundException("Account not found"));
        if (user.getRole() == Role.ADMIN) {
            throw new ForbiddenException("Administrator accounts require the controlled access-removal process");
        }
        verifyPasswordWhenPresent(user, request.currentPassword());

        // Stop future recurring charges and remove the upstream phone identity
        // before making the local account permanently unusable.
        cancelAutoPay(user);
        deleteFirebaseIdentity(user);

        UUID auditId = UUID.randomUUID();
        Instant now = Instant.now();
        jdbcTemplate.update("""
                insert into account_deletion_audits
                    (id, account_id, role, retention_policy_version, retained_data_summary,
                     requested_at, completed_at, created_at)
                values (?, ?, ?, ?, ?, ?, ?, ?)
                """, auditId, user.getId(), user.getRole().name(), RETENTION_POLICY_VERSION,
                RETAINED_DATA_SUMMARY, now, now, now);

        for (String storageKey : privateStorageKeys(user)) {
            jdbcTemplate.update("""
                    insert into account_deletion_storage_cleanup
                        (id, audit_id, storage_key, status, attempt_count, next_attempt_at, created_at, updated_at)
                    values (?, ?, ?, 'PENDING', 0, now(), now(), now())
                    """, UUID.randomUUID(), auditId, storageKey);
        }

        if (user.getRole() == Role.STUDENT) {
            anonymizeCustomer(user.getId());
        } else {
            anonymizeOwner(user.getId());
        }
        anonymizeSharedAccountData(user, now);
        return auditId;
    }

    private void verifyPasswordWhenPresent(User user, String currentPassword) {
        if (user.getPasswordHash() == null) return;
        if (currentPassword == null || currentPassword.isBlank()
                || !passwordEncoder.matches(currentPassword, user.getPasswordHash())) {
            throw new BadCredentialsException("Current password is required to delete this account");
        }
    }

    private void deleteFirebaseIdentity(User user) {
        if (user.getFirebaseSubject() == null) return;
        FirebaseAuth auth = firebaseAuth.getIfAvailable();
        if (auth == null) {
            throw new IllegalStateException("Firebase account cleanup is not available");
        }
        try {
            auth.deleteUser(user.getFirebaseSubject());
        } catch (FirebaseAuthException exception) {
            if (exception.getAuthErrorCode() != AuthErrorCode.USER_NOT_FOUND) {
                throw new IllegalStateException("Firebase account cleanup failed", exception);
            }
        }
    }

    private void cancelAutoPay(User user) {
        String sql = user.getRole() == Role.STUDENT
                ? """
                  select distinct am.razorpay_subscription_id
                  from autopay_mandates am
                  join students s on s.id = am.student_id
                  where s.user_id = ? and am.deleted_at is null
                    and am.status in ('PENDING_AUTHORIZATION', 'ACTIVE', 'PAUSED', 'FAILED')
                    and am.razorpay_subscription_id is not null
                  """
                : """
                  select distinct am.razorpay_subscription_id
                  from autopay_mandates am
                  join pgs p on p.id = am.pg_id
                  where p.owner_id = ? and am.deleted_at is null
                    and am.status in ('PENDING_AUTHORIZATION', 'ACTIVE', 'PAUSED', 'FAILED')
                    and am.razorpay_subscription_id is not null
                  """;
        List<String> subscriptionIds = jdbcTemplate.queryForList(sql, String.class, user.getId());
        if (!subscriptionIds.isEmpty() && !razorpayProperties.isConfigured()) {
            throw new IllegalStateException("Razorpay must be configured to stop active AutoPay before deletion");
        }
        subscriptionIds.forEach(razorpayGateway::cancelSubscription);

        String update = user.getRole() == Role.STUDENT
                ? """
                  update autopay_mandates am
                  set status = 'CANCELLED', failure_reason = 'Account deleted',
                      deleted_at = now(), updated_at = now()
                  from students s
                  where s.id = am.student_id and s.user_id = ? and am.deleted_at is null
                  """
                : """
                  update autopay_mandates am
                  set status = 'CANCELLED', failure_reason = 'Owner account deleted',
                      deleted_at = now(), updated_at = now()
                  from pgs p
                  where p.id = am.pg_id and p.owner_id = ? and am.deleted_at is null
                  """;
        jdbcTemplate.update(update, user.getId());
    }

    private Set<String> privateStorageKeys(User user) {
        Set<String> keys = new LinkedHashSet<>();
        if (user.getRole() == Role.STUDENT) {
            addKeys(keys, """
                    select cp.profile_photo_storage_key
                    from customer_profiles cp
                    where cp.user_id = ? and cp.profile_photo_storage_key is not null
                    """, user.getId());
            addKeys(keys, """
                    select d.storage_key
                    from customer_identity_documents d
                    join customer_profiles cp on cp.id = d.profile_id
                    where cp.user_id = ? and d.deleted_at is null and d.storage_key is not null
                    """, user.getId());
            addKeys(keys, """
                    select d.storage_key
                    from documents d join students s on s.id = d.student_id
                    where s.user_id = ? and d.deleted_at is null and d.storage_key is not null
                    """, user.getId());
        } else {
            addKeys(keys, """
                    select p.photo_storage_key from pgs p
                    where p.owner_id = ? and p.photo_storage_key is not null
                    """, user.getId());
            addKeys(keys, """
                    select ph.storage_key from pg_photos ph
                    join pgs p on p.id = ph.pg_id
                    where p.owner_id = ? and ph.deleted_at is null
                    """, user.getId());
            addKeys(keys, """
                    select d.storage_key from owner_kyc_documents d
                    join owner_kyc_submissions s on s.id = d.submission_id
                    join pgs p on p.id = s.pg_id
                    where p.owner_id = ? and d.deleted_at is null
                    """, user.getId());
        }
        keys.removeIf(key -> key == null || key.isBlank());
        return keys;
    }

    private void addKeys(Set<String> target, String sql, UUID userId) {
        target.addAll(new ArrayList<>(jdbcTemplate.queryForList(sql, String.class, userId)));
    }

    private void anonymizeCustomer(UUID userId) {
        jdbcTemplate.update("""
                update customer_identity_documents d
                set file_name = 'deleted', content_type = 'application/octet-stream', size_bytes = 1,
                    storage_key = 'deleted/' || d.id, deleted_at = now(), updated_at = now()
                from customer_profiles cp
                where cp.id = d.profile_id and cp.user_id = ? and d.deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update documents d
                set file_name = 'deleted', content_type = 'application/octet-stream', size_bytes = 0,
                    storage_key = null, deleted_at = now(), updated_at = now()
                from students s
                where s.id = d.student_id and s.user_id = ? and d.deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update customer_profiles
                set full_name = 'Deleted user', occupation = null, permanent_address = null,
                    guardian_name = null, guardian_phone = null, contact_phone = null,
                    identity_type = null, identity_last_four = null,
                    profile_photo_storage_key = null, profile_photo_file_name = null,
                    profile_photo_content_type = null, deleted_at = now(), updated_at = now()
                where user_id = ? and deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update complaints c
                set description = 'Content removed following account deletion.',
                    resolution_notes = null, deleted_at = now(), updated_at = now()
                from students s
                where s.id = c.student_id and s.user_id = ? and c.deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update students
                set full_name = 'Deleted user', phone = 'deleted-' || left(id::text, 12),
                    email = null, guardian_name = null, guardian_phone = null,
                    permanent_address = null, id_proof_number = null, updated_at = now()
                where user_id = ?
                """, userId);
        jdbcTemplate.update("""
                update pg_interest_requests
                set deleted_at = now(), updated_at = now()
                where customer_user_id = ? and deleted_at is null
                """, userId);
    }

    private void anonymizeOwner(UUID userId) {
        jdbcTemplate.update("""
                update owner_kyc_documents d
                set file_name = 'deleted', content_type = 'application/octet-stream', size_bytes = 0,
                    storage_key = 'deleted/' || d.id, deleted_at = now(), updated_at = now()
                from owner_kyc_submissions s join pgs p on p.id = s.pg_id
                where s.id = d.submission_id and p.owner_id = ? and d.deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update owner_kyc_submissions s
                set legal_name = 'Deleted owner', pan_last_four = '0000', aadhaar_last_four = '0000',
                    status = 'REJECTED', review_note = 'Account deleted',
                    deleted_at = now(), updated_at = now()
                from pgs p
                where p.id = s.pg_id and p.owner_id = ? and s.deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update pg_photos ph
                set storage_key = 'deleted/' || ph.id, original_file_name = 'deleted',
                    content_type = 'application/octet-stream', file_size = 0,
                    deleted_at = now(), updated_at = now()
                from pgs p
                where p.id = ph.pg_id and p.owner_id = ? and ph.deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update pg_direct_payment_settings s
                set enabled = false, beneficiary_name = 'Deleted owner', upi_id = 'deleted@invalid',
                    mobile_number = '0000000000', verified = false, verified_at = null,
                    deleted_at = now(), updated_at = now()
                from pgs p
                where p.id = s.pg_id and p.owner_id = ? and s.deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update pg_owner_contacts c
                set owner_name = null, normalized_mobile = 'deleted-' || left(c.id::text, 12),
                    deleted_at = now(), updated_at = now()
                from pgs p
                where p.id = c.pg_id and p.owner_id = ? and c.deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update owner_sms_messages m
                set recipient_mobile = 'deleted', message_text = 'Content removed following account deletion.',
                    provider_message_id = null, failure_reason = null,
                    deleted_at = now(), updated_at = now()
                from pgs p
                where p.id = m.pg_id and p.owner_id = ? and m.deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update pg_claim_requests
                set matched_mobile = 'deleted', status = 'REJECTED', review_note = 'Account deleted',
                    deleted_at = now(), updated_at = now()
                where claimant_user_id = ? and deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update pgs
                set owner_id = null, status = 'INACTIVE', claim_status = 'UNCLAIMED',
                    verification_status = 'UNVERIFIED', booking_enabled = false,
                    payment_onboarding_status = 'NOT_STARTED', razorpay_linked_account_id = null,
                    platform_commission_bps = 0, photo_storage_key = null,
                    deleted_at = now(), updated_at = now()
                where owner_id = ? and deleted_at is null
                """, userId);
    }

    private void anonymizeSharedAccountData(User user, Instant now) {
        UUID userId = user.getId();
        jdbcTemplate.update("""
                update refresh_tokens set revoked = true, deleted_at = now(), updated_at = now()
                where user_id = ? and deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update password_reset_tokens set consumed = true, deleted_at = now(), updated_at = now()
                where user_id = ? and deleted_at is null
                """, userId);
        jdbcTemplate.update("""
                update device_tokens
                set token = 'deleted-' || id::text, deleted_at = now(), updated_at = now()
                where user_id = ? and deleted_at is null
                """, userId);
        if (user.getPhone() != null) {
            jdbcTemplate.update("""
                    update otp_codes set consumed = true, deleted_at = now(), updated_at = now()
                    where phone = ? and deleted_at is null
                    """, user.getPhone());
        }
        jdbcTemplate.update("""
                update legal_acceptances
                set ip_address = null, user_agent = null, locale = null, updated_at = now()
                where user_id = ?
                """, userId);
        jdbcTemplate.update("""
                update support_tickets
                set subject = 'Deleted account request',
                    description = 'Content removed following account deletion.',
                    admin_response = null, deleted_at = now(), updated_at = now()
                where requester_user_id = ? and deleted_at is null
                """, userId);

        user.setEmail("deleted+" + userId + "@deleted.hipg.invalid");
        user.setPhone(null);
        user.setPasswordHash(null);
        user.setGoogleSubject(null);
        user.setFirebaseSubject(null);
        user.setFullName("Deleted user");
        user.setEmailVerified(false);
        user.setPhoneVerified(false);
        user.setStatus(UserStatus.DISABLED);
        user.setDeletedAt(now);
        userRepository.save(user);
    }
}
