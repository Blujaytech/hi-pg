package com.pgplatform.support;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.support.dto.SupportTicketAdminUpdateRequest;
import com.pgplatform.support.dto.SupportTicketCreateRequest;
import com.pgplatform.support.dto.SupportTicketResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class SupportTicketServiceTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SupportTicketService supportTicketService;

    @Test
    void customerAndOwnerCanTrackRequestsAndAdminCanRespond() {
        User customer = createUser(Role.STUDENT, "Customer One");
        User owner = createUser(Role.OWNER, "Owner One");
        User admin = createUser(Role.ADMIN, "Platform Admin");

        SupportTicketResponse customerTicket = supportTicketService.create(
                customer.getId(),
                Role.STUDENT,
                new SupportTicketCreateRequest(
                        SupportCategory.BOOKING,
                        "Booking is not updating",
                        "My confirmed booking is missing from the bookings screen."
                )
        );
        SupportTicketResponse ownerTicket = supportTicketService.create(
                owner.getId(),
                Role.OWNER,
                new SupportTicketCreateRequest(
                        SupportCategory.TECHNICAL,
                        "Owner dashboard issue",
                        "The dashboard cannot open the reports page."
                )
        );

        assertThat(supportTicketService.listMine(customer.getId()))
                .extracting(SupportTicketResponse::id)
                .containsExactly(customerTicket.id());
        assertThat(supportTicketService.listMine(owner.getId()))
                .extracting(SupportTicketResponse::id)
                .containsExactly(ownerTicket.id());

        List<SupportTicketResponse> adminQueue = supportTicketService.listForAdmin(SupportStatus.OPEN);
        assertThat(adminQueue)
                .extracting(SupportTicketResponse::id)
                .containsExactlyInAnyOrder(customerTicket.id(), ownerTicket.id());

        SupportTicketResponse updated = supportTicketService.respond(
                customerTicket.id(),
                admin.getId(),
                new SupportTicketAdminUpdateRequest(
                        SupportStatus.IN_PROGRESS,
                        "We found the booking and are correcting the account link."
                )
        );

        assertThat(updated.status()).isEqualTo(SupportStatus.IN_PROGRESS);
        assertThat(updated.adminResponse()).contains("correcting the account link");
        assertThat(updated.respondedByName()).isEqualTo("Platform Admin");
        assertThat(updated.respondedAt()).isNotNull();

        SupportTicketResponse trackedByCustomer = supportTicketService.listMine(customer.getId()).get(0);
        assertThat(trackedByCustomer.status()).isEqualTo(SupportStatus.IN_PROGRESS);
        assertThat(trackedByCustomer.adminResponse()).isEqualTo(updated.adminResponse());
    }

    private User createUser(Role role, String name) {
        User user = new User();
        user.setEmail(role.name().toLowerCase() + "-" + UUID.randomUUID() + "@example.com");
        user.setFullName(name);
        user.setRole(role);
        user.setProvider(AuthProviderType.LOCAL);
        return userRepository.save(user);
    }
}
