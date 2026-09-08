package com.pgplatform.student;

import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.discovery.BedAvailabilityBroadcaster;
import com.pgplatform.owner.Bed;
import com.pgplatform.owner.BedRepository;
import com.pgplatform.owner.BedStatus;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgService;
import com.pgplatform.student.dto.AssignBedRequest;
import com.pgplatform.student.dto.StudentCreateRequest;
import com.pgplatform.student.dto.StudentResponse;
import com.pgplatform.student.dto.StudentUpdateRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Owner-side student CRUD + bed assignment (technical plan §6 Phase 4).
 * Assigning/reassigning/freeing a bed here is what actually flips
 * Bed.status -- it's the only path that does, until Phase 11 booking exists.
 */
@Service
public class StudentService {

    private final StudentRepository studentRepository;
    private final BedRepository bedRepository;
    private final PgService pgService;
    private final BedAvailabilityBroadcaster broadcaster;

    public StudentService(StudentRepository studentRepository, BedRepository bedRepository, PgService pgService,
                           BedAvailabilityBroadcaster broadcaster) {
        this.studentRepository = studentRepository;
        this.bedRepository = bedRepository;
        this.pgService = pgService;
        this.broadcaster = broadcaster;
    }

    @Transactional
    public StudentResponse create(UUID pgId, UUID ownerId, StudentCreateRequest request) {
        Pg pg = pgService.requireOwnedPg(pgId, ownerId);

        Student student = new Student();
        student.setPg(pg);
        applyFields(student, request.fullName(), request.phone(), request.email(), request.guardianName(),
                request.guardianPhone(), request.permanentAddress(), request.idProofNumber(), request.dateOfJoining());
        student = studentRepository.save(student);

        if (request.bedId() != null && !request.bedId().isBlank()) {
            student = doAssignBed(student, pg, UUID.fromString(request.bedId()));
        }

        return StudentResponse.from(student);
    }

    @Transactional(readOnly = true)
    public List<StudentResponse> listForPg(UUID pgId, UUID ownerId) {
        pgService.requireOwnedPg(pgId, ownerId);
        return studentRepository.findAllByPgIdAndDeletedAtIsNullOrderByFullNameAsc(pgId)
                .stream().map(StudentResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public StudentResponse get(UUID studentId, UUID ownerId) {
        return StudentResponse.from(requireOwnedStudent(studentId, ownerId));
    }

    @Transactional
    public StudentResponse update(UUID studentId, UUID ownerId, StudentUpdateRequest request) {
        Student student = requireOwnedStudent(studentId, ownerId);
        applyFields(student, request.fullName(), request.phone(), request.email(), request.guardianName(),
                request.guardianPhone(), request.permanentAddress(), request.idProofNumber(), request.dateOfJoining());
        return StudentResponse.from(studentRepository.save(student));
    }

    @Transactional
    public StudentResponse assignBed(UUID studentId, UUID ownerId, AssignBedRequest request) {
        Student student = requireOwnedStudent(studentId, ownerId);
        if (student.getStatus() != StudentStatus.ACTIVE) {
            throw new ConflictException("Cannot assign a bed to a student who has moved out");
        }
        student = doAssignBed(student, student.getPg(), UUID.fromString(request.bedId()));
        return StudentResponse.from(student);
    }

    @Transactional
    public StudentResponse moveOut(UUID studentId, UUID ownerId) {
        Student student = requireOwnedStudent(studentId, ownerId);
        if (student.getBed() != null) {
            Bed bed = student.getBed();
            bed.setStatus(BedStatus.AVAILABLE);
            bedRepository.save(bed);
            student.setBed(null);
        }
        student.setStatus(StudentStatus.MOVED_OUT);
        student.setMoveOutDate(LocalDate.now());
        StudentResponse response = StudentResponse.from(studentRepository.save(student));
        broadcaster.notifyChanged(student.getPg().getId());
        return response;
    }

    @Transactional
    public void delete(UUID studentId, UUID ownerId) {
        Student student = requireOwnedStudent(studentId, ownerId);
        boolean hadBed = student.getBed() != null;
        if (student.getBed() != null) {
            Bed bed = student.getBed();
            bed.setStatus(BedStatus.AVAILABLE);
            bedRepository.save(bed);
        }
        student.markDeleted();
        studentRepository.save(student);
        if (hadBed) {
            broadcaster.notifyChanged(student.getPg().getId());
        }
    }

    private Student doAssignBed(Student student, Pg pg, UUID bedId) {
        Bed newBed = bedRepository.findByIdAndDeletedAtIsNull(bedId)
                .orElseThrow(() -> new NotFoundException("Bed not found"));

        if (!newBed.getRoom().getFloor().getPg().getId().equals(pg.getId())) {
            throw new ForbiddenException("That bed does not belong to this PG");
        }

        Bed previousBed = student.getBed();
        boolean alreadyOnThisBed = previousBed != null && previousBed.getId().equals(newBed.getId());

        if (!alreadyOnThisBed && newBed.getStatus() != BedStatus.AVAILABLE) {
            throw new ConflictException("That bed is not available");
        }

        if (previousBed != null && !alreadyOnThisBed) {
            previousBed.setStatus(BedStatus.AVAILABLE);
            bedRepository.save(previousBed);
        }

        newBed.setStatus(BedStatus.OCCUPIED);
        bedRepository.save(newBed);

        student.setBed(newBed);
        Student saved = studentRepository.save(student);
        broadcaster.notifyChanged(pg.getId());
        return saved;
    }

    private void applyFields(Student student, String fullName, String phone, String email, String guardianName,
                              String guardianPhone, String permanentAddress, String idProofNumber, LocalDate dateOfJoining) {
        student.setFullName(fullName);
        student.setPhone(phone);
        student.setEmail(email);
        student.setGuardianName(guardianName);
        student.setGuardianPhone(guardianPhone);
        student.setPermanentAddress(permanentAddress);
        student.setIdProofNumber(idProofNumber);
        student.setDateOfJoining(dateOfJoining);
    }

    public Student requireOwnedStudent(UUID studentId, UUID ownerId) {
        Student student = studentRepository.findByIdAndDeletedAtIsNull(studentId)
                .orElseThrow(() -> new NotFoundException("Student not found"));
        if (!student.getPg().getOwner().getId().equals(ownerId)) {
            throw new ForbiddenException("You do not have access to this student");
        }
        return student;
    }
}
