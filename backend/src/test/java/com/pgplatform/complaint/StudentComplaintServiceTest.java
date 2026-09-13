package com.pgplatform.complaint;

import com.pgplatform.auth.User;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.complaint.dto.ComplaintCreateRequest;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgService;
import com.pgplatform.student.Student;
import com.pgplatform.student.StudentRepository;
import com.pgplatform.student.StudentService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class StudentComplaintServiceTest {

    @Mock
    private ComplaintRepository complaintRepository;
    @Mock
    private StudentService studentService;
    @Mock
    private StudentRepository studentRepository;
    @Mock
    private PgService pgService;
    @Mock
    private NotificationService notificationService;
    @InjectMocks
    private ComplaintService complaintService;

    @Test
    void selfServiceCreateUsesLinkedStudentAndNotifiesOwner() {
        UUID userId = UUID.randomUUID();
        UUID studentId = UUID.randomUUID();
        UUID ownerId = UUID.randomUUID();
        UUID pgId = UUID.randomUUID();
        Student student = org.mockito.Mockito.mock(Student.class);
        Pg pg = org.mockito.Mockito.mock(Pg.class);
        User owner = org.mockito.Mockito.mock(User.class);

        when(studentRepository.findByUserIdAndDeletedAtIsNull(userId))
                .thenReturn(Optional.of(student));
        when(student.getId()).thenReturn(studentId);
        when(student.getFullName()).thenReturn("Asha Rao");
        when(student.getPg()).thenReturn(pg);
        when(pg.getId()).thenReturn(pgId);
        when(pg.getName()).thenReturn("Metro Residency");
        when(pg.getOwner()).thenReturn(owner);
        when(owner.getId()).thenReturn(ownerId);
        when(complaintRepository.save(any(Complaint.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        var response = complaintService.createForStudent(userId,
                new ComplaintCreateRequest(ComplaintCategory.MAINTENANCE,
                        ComplaintPriority.HIGH, "The bathroom tap is leaking."));

        assertThat(response.studentId()).isEqualTo(studentId);
        assertThat(response.pgName()).isEqualTo("Metro Residency");
        assertThat(response.status()).isEqualTo(ComplaintStatus.OPEN);
        verify(notificationService).notifyUser(ownerId, "New student complaint",
                "Asha Rao raised a maintenance complaint at Metro Residency.");
    }

    @Test
    void selfServiceListOnlyQueriesTheLinkedStudentId() {
        UUID userId = UUID.randomUUID();
        UUID studentId = UUID.randomUUID();
        Student student = org.mockito.Mockito.mock(Student.class);
        when(student.getId()).thenReturn(studentId);
        when(studentRepository.findByUserIdAndDeletedAtIsNull(userId))
                .thenReturn(Optional.of(student));
        when(complaintRepository.findAllByStudentIdAndDeletedAtIsNullOrderByCreatedAtDesc(studentId))
                .thenReturn(List.of());

        assertThat(complaintService.listForStudentUser(userId)).isEmpty();
        verify(complaintRepository)
                .findAllByStudentIdAndDeletedAtIsNullOrderByCreatedAtDesc(studentId);
    }

    @Test
    void selfServiceDetailRejectsAnotherStudentsComplaint() {
        UUID userId = UUID.randomUUID();
        UUID complaintId = UUID.randomUUID();
        Student caller = org.mockito.Mockito.mock(Student.class);
        Student otherStudent = org.mockito.Mockito.mock(Student.class);
        Complaint complaint = org.mockito.Mockito.mock(Complaint.class);

        when(caller.getId()).thenReturn(UUID.randomUUID());
        when(otherStudent.getId()).thenReturn(UUID.randomUUID());
        when(studentRepository.findByUserIdAndDeletedAtIsNull(userId))
                .thenReturn(Optional.of(caller));
        when(complaintRepository.findByIdAndDeletedAtIsNull(complaintId))
                .thenReturn(Optional.of(complaint));
        when(complaint.getStudent()).thenReturn(otherStudent);

        assertThatThrownBy(() -> complaintService.getForStudentUser(complaintId, userId))
                .isInstanceOf(ForbiddenException.class)
                .hasMessage("This complaint does not belong to you");
    }

    @Test
    void selfServiceRequiresABookingLinkedStudentProfile() {
        UUID userId = UUID.randomUUID();
        when(studentRepository.findByUserIdAndDeletedAtIsNull(userId))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> complaintService.listForStudentUser(userId))
                .isInstanceOf(NotFoundException.class)
                .hasMessageContaining("book a bed first");
    }
}
