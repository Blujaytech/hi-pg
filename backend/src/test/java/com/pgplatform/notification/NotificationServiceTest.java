package com.pgplatform.notification;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.notification.dto.DeviceTokenRegisterRequest;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

/**
 * Real Postgres (User, DeviceToken rows) via Testcontainers as usual --
 * only NotificationGateway itself is swapped for a Mockito mock, the same
 * role a Stub*Gateway plays elsewhere in this codebase (Razorpay, Document
 * storage) for an external dependency this environment can't actually call.
 */
class NotificationServiceTest extends AbstractIntegrationTest {

    @MockBean
    private NotificationGateway notificationGateway;

    @Autowired
    private NotificationService notificationService;
    @Autowired
    private UserRepository userRepository;
    @Autowired
    private DeviceTokenService deviceTokenService;

    private UUID createUser(String email) {
        User user = new User();
        user.setEmail(email);
        user.setPhone(email == null ? "9" + UUID.randomUUID().toString().replaceAll("\\D", "").substring(0, 9) : null);
        user.setFullName("Notify Test User");
        user.setRole(Role.STUDENT);
        user.setProvider(AuthProviderType.LOCAL);
        return userRepository.save(user).getId();
    }

    @Test
    void notifyingASendsEmailAndEveryRegisteredPushToken() {
        UUID userId = createUser("student-" + UUID.randomUUID() + "@example.com");
        deviceTokenService.register(userId, new DeviceTokenRegisterRequest("token-a", DevicePlatform.ANDROID));
        deviceTokenService.register(userId, new DeviceTokenRegisterRequest("token-b", DevicePlatform.IOS));

        notificationService.notifyUser(userId, "Hello", "World");

        verify(notificationGateway, times(1)).sendEmail(org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.eq("Hello"), org.mockito.ArgumentMatchers.eq("World"));

        ArgumentCaptor<String> tokenCaptor = ArgumentCaptor.forClass(String.class);
        verify(notificationGateway, times(2)).sendPush(tokenCaptor.capture(),
                org.mockito.ArgumentMatchers.eq("Hello"), org.mockito.ArgumentMatchers.eq("World"));
        assertThat(tokenCaptor.getAllValues()).containsExactlyInAnyOrder("token-a", "token-b");
    }

    @Test
    void notifyingAUserWithNoEmailAndNoDeviceTokensDoesNothing() {
        UUID userId = createUser(null);

        notificationService.notifyUser(userId, "Hello", "World");

        verify(notificationGateway, never()).sendEmail(org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyString());
        verify(notificationGateway, never()).sendPush(org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyString());
    }

    @Test
    void notifyingAnUnknownOrNullUserIdIsANoOpRatherThanThrowing() {
        notificationService.notifyUser(null, "Hello", "World");
        notificationService.notifyUser(UUID.randomUUID(), "Hello", "World");
        // no exception -- nothing further to assert
    }

    @Test
    void reRegisteringTheSameTokenUpdatesRatherThanDuplicates() {
        UUID userId = createUser("student2-" + UUID.randomUUID() + "@example.com");
        deviceTokenService.register(userId, new DeviceTokenRegisterRequest("shared-token", DevicePlatform.ANDROID));
        deviceTokenService.register(userId, new DeviceTokenRegisterRequest("shared-token", DevicePlatform.ANDROID));

        notificationService.notifyUser(userId, "Hi", "There");

        verify(notificationGateway, times(1)).sendPush(org.mockito.ArgumentMatchers.eq("shared-token"),
                org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyString());
    }
}
