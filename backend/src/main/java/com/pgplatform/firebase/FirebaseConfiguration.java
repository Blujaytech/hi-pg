package com.pgplatform.firebase;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.messaging.FirebaseMessaging;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;

import java.io.IOException;

@Configuration
public class FirebaseConfiguration {

    @Bean
    @ConditionalOnProperty(name = "app.firebase.enabled", havingValue = "true")
    FirebaseApp firebaseApp(FirebaseProperties properties) throws IOException {
        if (!StringUtils.hasText(properties.projectId())) {
            throw new IllegalStateException("FIREBASE_PROJECT_ID is required when Firebase is enabled");
        }
        FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.getApplicationDefault())
                .setProjectId(properties.projectId())
                .build();
        return FirebaseApp.initializeApp(options);
    }

    @Bean
    @ConditionalOnProperty(name = "app.firebase.enabled", havingValue = "true")
    FirebaseAuth firebaseAuth(FirebaseApp app) {
        return FirebaseAuth.getInstance(app);
    }

    @Bean
    @ConditionalOnProperty(name = "app.firebase.enabled", havingValue = "true")
    FirebaseMessaging firebaseMessaging(FirebaseApp app) {
        return FirebaseMessaging.getInstance(app);
    }
}
