package com.pgplatform.complaint;

import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.complaint.dto.ComplaintCreateRequest;
import com.pgplatform.complaint.dto.ComplaintResponse;
import com.pgplatform.complaint.dto.ComplaintStatusUpdateRequest;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.owner.PgService;
import com.pgplatform.student.Student;
import com.pgplatform.student.StudentRepository;
import com.pgplatform.student.StudentService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Service
public class ComplaintService {

    private static final Set<ComplaintStatus> RESOLVED_LIKE = Set.of(ComplaintStatus.RESOLVED, ComplaintStatus.CLOSED);

    private final ComplaintRepository complaintRepository;
    private final StudentService studentService;
    private final StudentRepository studentRepository;
    private final PgService pgService;
    private final NotificationService notificationService;

    public ComplaintService(ComplaintRepository complaintRepository, StudentService studentService,
                             StudentRepository studentRepository, PgService pgService,
                             NotificationService notificationService) {
        this.complaintRepository = complaintRepository;
        this.studentService = studentService;
        this.studentRepository = studentRepository;
        this.pgService = pgService;
        this.notificationService = notificationService;
    }

    @Transactional
    public ComplaintResponse create(UUID studentId, UUID ownerId, ComplaintCreateRequest request) {
        Student student = studentService.requireOwnedStudent(studentId, ownerId);

        return saveNewComplaint(student, request);
    }

    /** Self-service complaint filing for the authenticated Student login. */
    @Transactional
    public ComplaintResponse createForStudent(UUID userId, ComplaintCreateRequest request) {
        Student student = requireLinkedStudent(userId);
        ComplaintResponse response = saveNewComplaint(student, request);
        notificationService.notifyUser(student.getPg().getOwner().getId(), "New student complaint",
                student.getFullName() + " raised a " + request.category().name().toLowerCase()
                        + " complaint at " + student.getPg().getName() + ".");
        return response;
    }

    private ComplaintResponse saveNewComplaint(Student student, ComplaintCreateRequest request) {

        Complaint complaint = new Complaint();
        complaint.setStudent(student);
        complaint.setPg(student.getPg());
        complaint.setCategory(request.category());
        complaint.setPriority(request.priority() != null ? request.priority() : ComplaintPriority.MEDIUM);
        complaint.setDescription(request.description());
        complaint.setStatus(ComplaintStatus.OPEN);

        return ComplaintResponse.from(complaintRepository.save(complaint));
    }

    /** Self-service list, scoped from the JWT user id rather than a client-supplied student id. */
    @Transactional(readOnly = true)
    public List<ComplaintResponse> listForStudentUser(UUID userId) {
        Student student = requireLinkedStudent(userId);
        return complaintRepository.findAllByStudentIdAndDeletedAtIsNullOrderByCreatedAtDesc(student.getId())
                .stream().map(ComplaintResponse::from).toList();
    }

    /** Self-service detail with an explicit cross-student ownership check. */
    @Transactional(readOnly = true)
    public ComplaintResponse getForStudentUser(UUID complaintId, UUID userId) {
        Student student = requireLinkedStudent(userId);
        Complaint complaint = complaintRepository.findByIdAndDeletedAtIsNull(complaintId)
                .orElseThrow(() -> new NotFoundException("Complaint not found"));
        if (!complaint.getStudent().getId().equals(student.getId())) {
            throw new ForbiddenException("This complaint does not belong to you");
        }
        return ComplaintResponse.from(complaint);
    }

    @Transactional(readOnly = true)
    public List<ComplaintResponse> listForStudent(UUID studentId, UUID ownerId) {
        studentService.requireOwnedStudent(studentId, ownerId);
        return complaintRepository.findAllByStudentIdAndDeletedAtIsNullOrderByCreatedAtDesc(studentId)
                .stream().map(ComplaintResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<ComplaintResponse> listForPg(UUID pgId, UUID ownerId) {
        pgService.requireOwnedPg(pgId, ownerId);
        return complaintRepository.findAllByPgIdAndDeletedAtIsNullOrderByCreatedAtDesc(pgId)
                .stream().map(ComplaintResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public ComplaintResponse get(UUID complaintId, UUID ownerId) {
        return ComplaintResponse.from(requireOwnedComplaint(complaintId, ownerId));
    }

    @Transactional
    public ComplaintResponse updateStatus(UUID complaintId, UUID ownerId, ComplaintStatusUpdateRequest request) {
        Complaint complaint = requireOwnedComplaint(complaintId, ownerId);

        if (request.status() == ComplaintStatus.RESOLVED
                && (request.resolutionNotes() == null || request.resolutionNotes().isBlank())) {
            throw new ConflictException("Resolution notes are required when marking a complaint resolved");
        }

        complaint.setStatus(request.status());
        if (request.resolutionNotes() != null && !request.resolutionNotes().isBlank()) {
            complaint.setResolutionNotes(request.resolutionNotes());
        }
        complaint.setResolvedAt(RESOLVED_LIKE.contains(request.status()) ? Instant.now() : null);
        Complaint saved = complaintRepository.save(complaint);

        // Only reachable for a student who has a linked login (Phase 11+, ADR-0018) -- most complaints today are
        // owner-logged on behalf of a student with no login at all (ADR-0009), so this is often a no-op, by design.
        if (request.status() == ComplaintStatus.RESOLVED && saved.getStudent().getUser() != null) {
            notificationService.notifyUser(saved.getStudent().getUser().getId(), "Complaint resolved",
                    "Your complaint (\"" + saved.getDescription() + "\") has been marked resolved.");
        }

        return ComplaintResponse.from(saved);
    }

    @Transactional
    public void delete(UUID complaintId, UUID ownerId) {
        Complaint complaint = requireOwnedComplaint(complaintId, ownerId);
        complaint.markDeleted();
        complaintRepository.save(complaint);
    }

    private Complaint requireOwnedComplaint(UUID complaintId, UUID ownerId) {
        Complaint complaint = complaintRepository.findByIdAndDeletedAtIsNull(complaintId)
                .orElseThrow(() -> new NotFoundException("Complaint not found"));
        if (!complaint.getPg().getOwner().getId().equals(ownerId)) {
            throw new ForbiddenException("You do not have access to this complaint");
        }
        return complaint;
    }

    private Student requireLinkedStudent(UUID userId) {
        return studentRepository.findByUserIdAndDeletedAtIsNull(userId)
                .orElseThrow(() -> new NotFoundException(
                        "You don't have a student profile yet -- book a bed first"));
    }
}
