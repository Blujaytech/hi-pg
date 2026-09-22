package com.pgplatform.payment;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.booking.BookingPaymentChannel;
import com.pgplatform.booking.BookingRepository;
import com.pgplatform.booking.BookingService;
import com.pgplatform.booking.BookingStatus;
import com.pgplatform.booking.dto.BookingCreateRequest;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.onboarding.OwnerKycStatus;
import com.pgplatform.onboarding.OwnerKycSubmission;
import com.pgplatform.onboarding.OwnerKycSubmissionRepository;
import com.pgplatform.owner.*;
import com.pgplatform.owner.dto.DirectPaymentSettingsUpdateRequest;
import com.pgplatform.owner.dto.FloorCreateRequest;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.owner.dto.RoomCreateRequest;
import com.pgplatform.payment.dto.DirectPaymentApproveRequest;
import com.pgplatform.payment.dto.DirectPaymentSubmitRequest;
import com.pgplatform.student.CustomerProfileService;
import com.pgplatform.student.IdentityType;
import com.pgplatform.student.dto.CustomerProfileUpdateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DirectPaymentFlowTest extends AbstractIntegrationTest {

    @Autowired private UserRepository userRepository;
    @Autowired private PgRepository pgRepository;
    @Autowired private PgService pgService;
    @Autowired private FloorService floorService;
    @Autowired private RoomService roomService;
    @Autowired private BedRepository bedRepository;
    @Autowired private BookingRepository bookingRepository;
    @Autowired private BookingService bookingService;
    @Autowired private CustomerProfileService profileService;
    @Autowired private OwnerKycSubmissionRepository kycRepository;
    @Autowired private DirectPaymentSettingsService settingsService;
    @Autowired private DirectPaymentService directPaymentService;
    @Autowired private DashboardService dashboardService;

    @Test
    void customerClaimNeverAllocatesAndOnlyCorrectOwnerCanApproveExactAmount() {
        Fixture fixture = fixture();

        var booking = bookingService.book(fixture.customerId(),
                new BookingCreateRequest(fixture.bedId(), LocalDate.now()));
        var details = directPaymentService.selectDirectPayment(booking.id(), fixture.customerId());
        assertThat(details.amount()).isEqualByComparingTo("6500.00");
        assertThat(bookingRepository.findByIdAndDeletedAtIsNull(booking.id()).orElseThrow()
                .getPaymentChannel()).isEqualTo(BookingPaymentChannel.DIRECT_UPI);

        assertThatThrownBy(() -> bookingService.claimOnlinePaymentChannel(booking.id(), fixture.customerId()))
                .isInstanceOf(ConflictException.class);

        var submitted = directPaymentService.submit(booking.id(), fixture.customerId(),
                new DirectPaymentSubmitRequest("claim-" + booking.id(), "UPI123456789", true));
        var duplicate = directPaymentService.submit(booking.id(), fixture.customerId(),
                new DirectPaymentSubmitRequest("claim-" + booking.id(), "UPI123456789", true));
        assertThat(duplicate.id()).isEqualTo(submitted.id());

        var held = bookingRepository.findByIdAndDeletedAtIsNull(booking.id()).orElseThrow();
        assertThat(held.getStatus()).isEqualTo(BookingStatus.DIRECT_PAYMENT_REVIEW);
        assertThat(bedRepository.findByIdAndDeletedAtIsNull(fixture.bedId()).orElseThrow().getStatus())
                .isEqualTo(BedStatus.AVAILABLE);

        User anotherOwner = owner("other-" + UUID.randomUUID() + "@example.com", "+919800000099");
        assertThatThrownBy(() -> directPaymentService.approve(submitted.id(), anotherOwner.getId(),
                new DirectPaymentApproveRequest(new BigDecimal("6500.00"),
                        "approve-other-" + submitted.id(), null)))
                .isInstanceOf(ForbiddenException.class);
        assertThatThrownBy(() -> directPaymentService.approve(submitted.id(), fixture.ownerId(),
                new DirectPaymentApproveRequest(new BigDecimal("6499.99"),
                        "approve-wrong-" + submitted.id(), null)))
                .isInstanceOf(ConflictException.class);

        var approved = directPaymentService.approve(submitted.id(), fixture.ownerId(),
                new DirectPaymentApproveRequest(new BigDecimal("6500.00"),
                        "approve-" + submitted.id(), "Matched bank statement"));
        var approvedRetry = directPaymentService.approve(submitted.id(), fixture.ownerId(),
                new DirectPaymentApproveRequest(new BigDecimal("6500.00"),
                        "approve-" + submitted.id(), "Matched bank statement"));

        assertThat(approved.status()).isEqualTo(DirectPaymentStatus.APPROVED);
        assertThat(approvedRetry.id()).isEqualTo(approved.id());
        assertThat(bookingRepository.findByIdAndDeletedAtIsNull(booking.id()).orElseThrow().getStatus())
                .isEqualTo(BookingStatus.CHECKED_IN);
        assertThat(bedRepository.findByIdAndDeletedAtIsNull(fixture.bedId()).orElseThrow().getStatus())
                .isEqualTo(BedStatus.OCCUPIED);
        assertThat(dashboardService.forOwner(fixture.ownerId()).collectedThisMonth())
                .isEqualByComparingTo("6500.00");
    }

    private Fixture fixture() {
        User owner = owner("direct-" + UUID.randomUUID() + "@example.com", "+919800000001");
        UUID pgId = pgService.create(owner.getId(), new PgCreateRequest(
                "Direct Pay PG", "1 Test Street", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        Pg pg = pgRepository.findByIdAndDeletedAtIsNull(pgId).orElseThrow();

        OwnerKycSubmission kyc = new OwnerKycSubmission();
        kyc.setPg(pg);
        kyc.setLegalName(owner.getFullName());
        kyc.setPanLastFour("1234");
        kyc.setAadhaarLastFour("5678");
        kyc.setStatus(OwnerKycStatus.VERIFIED);
        kycRepository.save(kyc);
        settingsService.update(pgId, owner.getId(), new DirectPaymentSettingsUpdateRequest(
                true, owner.getFullName(), "directowner@upi", owner.getPhone()));

        UUID floorId = floorService.create(pgId, owner.getId(),
                new FloorCreateRequest("Ground", 0)).id();
        UUID bedId = roomService.create(floorId, owner.getId(), new RoomCreateRequest(
                "G-1", 1, new BigDecimal("6500.00"), RoomType.NON_AC)).beds().get(0).id();

        User customer = new User();
        customer.setFullName("Direct Customer");
        customer.setPhone("9000000021");
        customer.setPhoneVerified(true);
        customer.setRole(Role.STUDENT);
        customer.setProvider(AuthProviderType.LOCAL);
        customer = userRepository.save(customer);
        profileService.update(customer.getId(), new CustomerProfileUpdateRequest(
                "Direct Customer", "Student", "22 Customer Road",
                IdentityType.VOTER_ID, "C9D8", true, true, false),
                "127.0.0.1", "test", "en-IN");
        return new Fixture(owner.getId(), customer.getId(), bedId);
    }

    private User owner(String email, String phone) {
        User owner = new User();
        owner.setEmail(email);
        owner.setPhone(phone);
        owner.setPhoneVerified(true);
        owner.setFullName("Verified Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        return userRepository.save(owner);
    }

    private record Fixture(UUID ownerId, UUID customerId, UUID bedId) {}
}
