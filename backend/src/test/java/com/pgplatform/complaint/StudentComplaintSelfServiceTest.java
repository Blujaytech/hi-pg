package com.pgplatform.complaint;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.complaint.dto.ComplaintCreateRequest;
import com.pgplatform.complaint.dto.ComplaintResponse;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.student.Student;
import com.pgplatform.student.StudentRepository;
import com.pgplatform.student.StudentStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StudentComplaintSelfServiceTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private StudentRepository studentRepository;
    @Autowired
    private PgService pgService;
    @Autowired
    private ComplaintService complaintService;

    @Test
    void linkedStudentCanFileListAndReadTheirComplaint() {
        User owner = createUser(Role.OWNER);
        User studentUser = createUser(Role.STUDENT);
        Student student = linkStudent(studentUser, owner, "Comfort Stay");

        ComplaintResponse created = complaintService.createForStudent(studentUser.getId(),
                new ComplaintCreateRequest(ComplaintCategory.CLEANLINESS, ComplaintPriority.HIGH,
                        "The common kitchen needs cleaning."));

        assertThat(created.studentId()).isEqualTo(student.getId());
        assertThat(created.pgName()).isEqualTo("Comfort Stay");
        assertThat(created.status()).isEqualTo(ComplaintStatus.OPEN);
        assertThat(complaintService.listForStudentUser(studentUser.getId()))
                .extracting(ComplaintResponse::id)
                .contains(created.id());
        assertThat(complaintService.getForStudentUser(created.id(), studentUser.getId()).id())
                .isEqualTo(created.id());
    }

    @Test
    void studentCannotReadAnotherStudentsComplaint() {
        User owner = createUser(Role.OWNER);
        User firstUser = createUser(Role.STUDENT);
        User secondUser = createUser(Role.STUDENT);
        linkStudent(firstUser, owner, "Metro Residency");
        linkStudent(secondUser, owner, "Green Valley PG");

        ComplaintResponse complaint = complaintService.createForStudent(firstUser.getId(),
                new ComplaintCreateRequest(ComplaintCategory.SECURITY, ComplaintPriority.MEDIUM,
                        "The entrance light is not working."));

        assertThatThrownBy(() -> complaintService.getForStudentUser(complaint.id(), secondUser.getId()))
                .isInstanceOf(ForbiddenException.class);
    }

    @Test
    void loginWithoutLinkedStudentRecordGetsActionableError() {
        User studentUser = createUser(Role.STUDENT);

        assertThatThrownBy(() -> complaintService.listForStudentUser(studentUser.getId()))
                .isInstanceOf(NotFoundException.class)
                .hasMessageContaining("book a bed first");
    }

    private User createUser(Role role) {
        User user = new User();
        String unique = UUID.randomUUID().toString();
        user.setFullName(role == Role.OWNER ? "Test Owner" : "Test Student");
        user.setRole(role);
        user.setProvider(AuthProviderType.LOCAL);
        if (role == Role.OWNER) {
            user.setEmail(unique + "@example.com");
        } else {
            user.setPhone(unique.substring(0, 12));
        }
        return userRepository.save(user);
    }

    private Student linkStudent(User user, User owner, String pgName) {
        UUID pgId = pgService.create(owner.getId(), new PgCreateRequest(
                pgName, "12 Main Road", "Hyderabad", "Telangana", "500001",
                null, null, "A well managed property", GenderPreference.CO_ED)).id();
        Pg pg = pgService.requireOwnedPg(pgId, owner.getId());

        Student student = new Student();
        student.setUser(user);
        student.setPg(pg);
        student.setFullName(user.getFullName());
        student.setPhone(user.getPhone());
        student.setDateOfJoining(LocalDate.now());
        student.setStatus(StudentStatus.ACTIVE);
        return studentRepository.save(student);
    }
}
