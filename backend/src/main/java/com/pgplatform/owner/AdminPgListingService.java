package com.pgplatform.owner;

import com.pgplatform.auth.PhoneNumbers;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.document.DocumentStorageGateway;
import com.pgplatform.owner.dto.AdminPgListingRequest;
import com.pgplatform.owner.dto.AdminPgListingResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.util.List;
import java.util.UUID;

@Service
public class AdminPgListingService {
    private final PgRepository pgRepository;
    private final PgOwnerContactRepository contactRepository;
    private final PgInterestRequestRepository interestRepository;
    private final PgPhotoRepository photoRepository;
    private final OwnerSmsService smsService;
    private final DocumentStorageGateway storageGateway;

    public AdminPgListingService(PgRepository pgRepository, PgOwnerContactRepository contactRepository,
                                 PgInterestRequestRepository interestRepository,
                                 PgPhotoRepository photoRepository, OwnerSmsService smsService,
                                 DocumentStorageGateway storageGateway) {
        this.pgRepository = pgRepository;
        this.contactRepository = contactRepository;
        this.interestRepository = interestRepository;
        this.photoRepository = photoRepository;
        this.smsService = smsService;
        this.storageGateway = storageGateway;
    }

    @Transactional
    public AdminPgListingResponse create(AdminPgListingRequest request) {
        Pg pg = new Pg();
        apply(pg, request);
        pg.setOwner(null);
        pg.setAdminCreated(true);
        pg.setClaimStatus(PgClaimStatus.UNCLAIMED);
        pg.setVerificationStatus(PgVerificationStatus.UNVERIFIED);
        pg.setBookingEnabled(false);
        pg = pgRepository.save(pg);

        PgOwnerContact contact = saveContact(pg, request.ownerName(), request.ownerMobile());
        invite(pg, contact);
        return response(pg, contact);
    }

    @Transactional(readOnly = true)
    public List<AdminPgListingResponse> list() {
        return pgRepository.findAllByDeletedAtIsNullOrderByCreatedAtDesc().stream()
                .map(pg -> response(pg, contactRepository.findByPgIdAndDeletedAtIsNull(pg.getId()).orElse(null)))
                .toList();
    }

    @Transactional
    public AdminPgListingResponse update(UUID pgId, AdminPgListingRequest request) {
        Pg pg = pgRepository.findLockedByIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("PG not found"));
        apply(pg, request);
        PgOwnerContact contact = contactRepository.findByPgIdAndDeletedAtIsNull(pgId).orElse(null);
        if (hasText(request.ownerMobile())) {
            if (contact == null) contact = new PgOwnerContact();
            contact.setPg(pg);
            contact.setOwnerName(trim(request.ownerName()));
            contact.setNormalizedMobile(PhoneNumbers.normalize(request.ownerMobile()));
            if (contact.getInvitationStatus() == null) contact.setInvitationStatus(PgInvitationStatus.NOT_SENT);
            contact = contactRepository.save(contact);
        } else if (contact != null) {
            contact.markDeleted();
            contactRepository.save(contact);
            contact = null;
        }
        return response(pgRepository.save(pg), contact);
    }

    @Transactional
    public AdminPgListingResponse retryInvitation(UUID pgId) {
        Pg pg = pgRepository.findLockedByIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("PG not found"));
        PgOwnerContact contact = contactRepository.findByPgIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new IllegalArgumentException("Add a valid owner mobile before sending an invitation"));
        invite(pg, contact);
        return response(pg, contact);
    }

    @Transactional
    public void delete(UUID pgId) {
        Pg pg = pgRepository.findLockedByIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("PG not found"));
        contactRepository.findByPgIdAndDeletedAtIsNull(pgId).ifPresent(contact -> {
            contact.markDeleted();
            contactRepository.save(contact);
        });
        pg.markDeleted();
        pgRepository.save(pg);
    }

    private void apply(Pg pg, AdminPgListingRequest request) {
        pg.setName(request.name().trim());
        pg.setAddress(request.address().trim());
        pg.setCity(SupportedCities.requireCanonical(request.city()));
        pg.setState(trim(request.state()));
        pg.setPincode(trim(request.pincode()));
        pg.setLatitude(request.latitude());
        pg.setLongitude(request.longitude());
        pg.setLocationUrl(LocationUrls.normalizeGoogleMapsUrl(request.locationUrl()));
        pg.setDescription(trim(request.description()));
        pg.setGenderPreference(request.genderPreference());
        pg.setStatus(PgStatus.ACTIVE);
    }

    private AdminPgListingResponse response(Pg pg, PgOwnerContact contact) {
        OwnerSmsResult delivery = smsService.delivery(pg.getId(), "ADMIN_LISTING_INVITATION");
        return new AdminPgListingResponse(pg.getId(), pg.getName(), pg.getAddress(), pg.getCity(), pg.getState(),
                pg.getPincode(), pg.getLatitude(), pg.getLongitude(), pg.getLocationUrl(), pg.getDescription(),
                photoUrl(pg), pg.getGenderPreference(),
                pg.getStatus(), pg.getClaimStatus(), pg.getVerificationStatus(), pg.isBookingEnabled(),
                contact == null ? null : contact.getOwnerName(),
                contact == null ? null : contact.getNormalizedMobile(),
                contact == null ? PgInvitationStatus.NOT_SENT : contact.getInvitationStatus(),
                delivery == null ? null : delivery.status(),
                delivery == null ? null : delivery.failureReason(),
                interestRepository.countByPgIdAndDeletedAtIsNull(pg.getId()), pg.getCreatedAt());
    }

    private String photoUrl(Pg pg) {
        if (pg.getPhotoStorageKey() == null) return null;
        if (PgPhotoUrls.isDatabaseStorageKey(pg.getPhotoStorageKey())) {
            return photoRepository.findByStorageKeyAndDeletedAtIsNull(pg.getPhotoStorageKey())
                    .map(PgPhotoUrls::databaseUrl)
                    .orElse(null);
        }
        return storageGateway.generateSignedUrl(pg.getPhotoStorageKey(), Duration.ofHours(1));
    }

    private String trim(String value) { return value == null || value.isBlank() ? null : value.trim(); }

    public PgOwnerContact saveContact(Pg pg, String ownerName, String ownerMobile) {
        if (!hasText(ownerMobile)) return null;
        PgOwnerContact contact = new PgOwnerContact();
        contact.setPg(pg);
        contact.setOwnerName(trim(ownerName));
        contact.setNormalizedMobile(PhoneNumbers.normalize(ownerMobile));
        contact.setInvitationStatus(PgInvitationStatus.PENDING_PROVIDER);
        return contactRepository.save(contact);
    }

    public PgInvitationStatus invite(Pg pg, PgOwnerContact contact) {
        if (contact == null) return PgInvitationStatus.NOT_SENT;
        OwnerSmsResult sms = smsService.sendOnce(pg, "ADMIN_LISTING_INVITATION", contact.getNormalizedMobile(),
                "Hi PG has listed " + pg.getName() + ". Claim and verify your property to manage it and accept "
                        + "bookings: " + smsService.claimUrl());
        if (sms.sent()) {
            contact.setInvitationStatus(PgInvitationStatus.SENT);
            contact.setInvitedAt(java.time.Instant.now());
            contactRepository.save(contact);
        }
        return contact.getInvitationStatus();
    }

    private boolean hasText(String value) { return value != null && !value.isBlank(); }
}
