package com.pgplatform.auth;

import com.pgplatform.auth.dto.OwnerPhoneOtpRequest;
import com.pgplatform.auth.dto.OwnerPhoneOtpVerifyRequest;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.NotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class OwnerPhoneVerificationService {
    private final UserRepository userRepository;
    private final OtpService otpService;

    public OwnerPhoneVerificationService(UserRepository userRepository, OtpService otpService) {
        this.userRepository = userRepository;
        this.otpService = otpService;
    }

    public void request(UUID ownerId, OwnerPhoneOtpRequest request) {
        requireOwner(ownerId);
        userRepository.findByPhoneAndDeletedAtIsNull(request.phone())
                .filter(user -> !user.getId().equals(ownerId))
                .ifPresent(user -> { throw new ConflictException("This phone number is already in use"); });
        otpService.requestOtp(request.phone(), OtpPurpose.OWNER_PHONE_VERIFICATION);
    }

    @Transactional
    public void verify(UUID ownerId, OwnerPhoneOtpVerifyRequest request) {
        User owner = requireOwner(ownerId);
        if (!otpService.verifyOtp(request.phone(), request.code(), OtpPurpose.OWNER_PHONE_VERIFICATION)) {
            throw new ConflictException("The OTP is invalid or expired");
        }
        userRepository.findByPhoneAndDeletedAtIsNull(request.phone())
                .filter(user -> !user.getId().equals(ownerId))
                .ifPresent(user -> { throw new ConflictException("This phone number is already in use"); });
        owner.setPhone(request.phone());
        owner.setPhoneVerified(true);
        userRepository.save(owner);
    }

    private User requireOwner(UUID ownerId) {
        User owner = userRepository.findByIdAndDeletedAtIsNull(ownerId)
                .orElseThrow(() -> new NotFoundException("Owner account not found"));
        if (owner.getRole() != Role.OWNER) {
            throw new ConflictException("Only owners can verify an owner phone number");
        }
        return owner;
    }
}
