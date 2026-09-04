package com.pgplatform.complaint;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.complaint.dto.ComplaintCreateRequest;
import com.pgplatform.complaint.dto.ComplaintResponse;
import com.pgplatform.complaint.dto.ComplaintStatusUpdateRequest;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.student.StudentService;
import com.pgplatform.student.dto.StudentCreateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ComplaintLifecycleTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PgService pgService;
    @Autowired
    private StudentService studentService;
    @Autowired
    private ComplaintService complaintService;

    private UUID createOwner(String email) {
        User owner = new User();
        owner.setEmail(email);
        owner.setFullName("Owner " + email);
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        return userRepository.save(owner).getId();
    }

    @Test
    void resolvingWithoutNotesIsRejectedThenSucceedsWithNotes() {
        UUID ownerId = createOwner("owner-" + UUID.randomUUID() + "@example.com");
        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Sunrise PG", "12 MG Road", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID studentId = studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Asha Rao", "9999999999", null, null, null, null, null, LocalDate.now(), null)).id();

        ComplaintResponse complaint = complaintService.create(studentId, ownerId,
                new ComplaintCreateRequest(ComplaintCategory.MAINTENANCE, ComplaintPriority.HIGH, "Leaking tap in bathroom"));
        assertThat(complaint.status()).isEqualTo(ComplaintStatus.OPEN);

        assertThatThrownBy(() -> complaintService.updateStatus(complaint.id(), ownerId,
                new ComplaintStatusUpdateRequest(ComplaintStatus.RESOLVED, null)))
                .isInstanceOf(ConflictException.class);

        ComplaintResponse resolved = complaintService.updateStatus(complaint.id(), ownerId,
                new ComplaintStatusUpdateRequest(ComplaintStatus.RESOLVED, "Plumber fixed it same day"));
        assertThat(resolved.status()).isEqualTo(ComplaintStatus.RESOLVED);
        assertThat(resolved.resolvedAt()).isNotNull();
        assertThat(resolved.resolutionNotes()).isEqualTo("Plumber fixed it same day");
    }

    @Test
    void anotherOwnerCannotSeeOrUpdateTheComplaint() {
        UUID ownerA = createOwner("a-" + UUID.randomUUID() + "@example.com");
        UUID ownerB = createOwner("b-" + UUID.randomUUID() + "@example.com");
        UUID pgId = pgService.create(ownerA, new PgCreateRequest("Sunrise PG", "12 MG Road", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID studentId = studentService.create(pgId, ownerA, new StudentCreateRequest(
                "Asha Rao", "9999999999", null, null, null, null, null, LocalDate.now(), null)).id();
        ComplaintResponse complaint = complaintService.create(studentId, ownerA,
                new ComplaintCreateRequest(ComplaintCategory.NOISE, null, "Loud music at night"));

        assertThatThrownBy(() -> complaintService.get(complaint.id(), ownerB)).isInstanceOf(ForbiddenException.class);
        assertThatThrownBy(() -> complaintService.updateStatus(complaint.id(), ownerB,
                new ComplaintStatusUpdateRequest(ComplaintStatus.CLOSED, null)))
                .isInstanceOf(ForbiddenException.class);
    }
}
