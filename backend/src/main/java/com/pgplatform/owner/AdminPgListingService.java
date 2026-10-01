package com.pgplatform.owner;

import com.pgplatform.auth.PhoneNumbers;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.owner.dto.AdminPgListingRequest;
import com.pgplatform.owner.dto.AdminPgListingResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class AdminPgListingService {
    private final PgRepository pgRepository;
    private final PgOwnerContactRepository contactRepository;
    private final PgInterestRequestRepository interestRepository;
    private final OwnerSmsService smsService;

    public AdminPgListingService(PgRepository pgRepository, PgOwnerContactRepository contactRepository,
                                 PgInterestRequestRepository interestRepository,
                                 OwnerSmsService smsService) {
        this.pgRepository = pgRepository;
        this.contactRepository = contactRepository;
        this.interestRepository = interestRepository;
        this.smsService = smsService;
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

        PgOwnerContact contact = new PgOwnerContact();
        contact.setPg(pg);
        contact.setOwnerName(request.ownerName().trim());
        contact.setNormalizedMobile(PhoneNumbers.normalize(request.ownerMobile()));
        contact.setInvitationStatus(PgInvitationStatus.PENDING_PROVIDER);
        contact = contactRepository.save(contact);
        OwnerSmsResult sms = smsService.sendOnce(pg, "ADMIN_LISTING_INVITATION", contact.getNormalizedMobile(),
                "Hi PG has listed " + pg.getName() + ". Claim and verify your property to manage it and accept "
                        + "bookings: " + smsService.claimUrl());
        if (sms.sent()) {
            contact.setInvitationStatus(PgInvitationStatus.SENT);
            contact.setInvitedAt(java.time.Instant.now());
            contactRepository.save(contact);
        }
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
        PgOwnerContact contact = contactRepository.findByPgIdAndDeletedAtIsNull(pgId)
                .orElseGet(PgOwnerContact::new);
        contact.setPg(pg);
        contact.setOwnerName(request.ownerName().trim());
        contact.setNormalizedMobile(PhoneNumbers.normalize(request.ownerMobile()));
        if (contact.getInvitationStatus() == null) contact.setInvitationStatus(PgInvitationStatus.PENDING_PROVIDER);
        return response(pgRepository.save(pg), contactRepository.save(contact));
    }

    private void apply(Pg pg, AdminPgListingRequest request) {
        pg.setName(request.name().trim());
        pg.setAddress(request.address().trim());
        pg.setCity(SupportedCities.requireCanonical(request.city()));
        pg.setState(trim(request.state()));
        pg.setPincode(trim(request.pincode()));
        pg.setLatitude(request.latitude());
        pg.setLongitude(request.longitude());
        pg.setDescription(trim(request.description()));
        pg.setGenderPreference(request.genderPreference());
        pg.setStatus(PgStatus.ACTIVE);
    }

    private AdminPgListingResponse response(Pg pg, PgOwnerContact contact) {
        return new AdminPgListingResponse(pg.getId(), pg.getName(), pg.getAddress(), pg.getCity(), pg.getState(),
                pg.getPincode(), pg.getLatitude(), pg.getLongitude(), pg.getDescription(), pg.getGenderPreference(),
                pg.getStatus(), pg.getClaimStatus(), pg.getVerificationStatus(), pg.isBookingEnabled(),
                contact == null ? null : contact.getOwnerName(),
                contact == null ? null : contact.getNormalizedMobile(),
                contact == null ? PgInvitationStatus.NOT_SENT : contact.getInvitationStatus(),
                interestRepository.countByPgIdAndDeletedAtIsNull(pg.getId()), pg.getCreatedAt());
    }

    private String trim(String value) { return value == null || value.isBlank() ? null : value.trim(); }
}
