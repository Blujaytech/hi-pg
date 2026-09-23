package com.pgplatform.document;

import jakarta.annotation.PreDestroy;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.S3ClientBuilder;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.UUID;

/** Stores sensitive documents in a private S3-compatible bucket. */
@Component
@ConditionalOnProperty(name = "app.storage.s3.enabled", havingValue = "true")
public class S3DocumentStorageGateway implements DocumentStorageGateway {

    private final S3StorageProperties properties;
    private final S3Client client;
    private final S3Presigner presigner;

    public S3DocumentStorageGateway(S3StorageProperties properties) {
        properties.validate();
        this.properties = properties;

        StaticCredentialsProvider credentials = StaticCredentialsProvider.create(
                AwsBasicCredentials.create(properties.getAccessKey(), properties.getSecretKey()));
        S3Configuration serviceConfiguration = S3Configuration.builder()
                .pathStyleAccessEnabled(properties.isPathStyleAccess())
                .build();

        S3ClientBuilder clientBuilder = S3Client.builder()
                .region(Region.of(properties.getRegion()))
                .credentialsProvider(credentials)
                // Do not rely on classpath auto-detection: Spring Boot 3.2
                // manages an Apache HttpClient version older than the AWS SDK
                // expects. The JDK transport has no such version coupling.
                .httpClientBuilder(UrlConnectionHttpClient.builder())
                .serviceConfiguration(serviceConfiguration);
        S3Presigner.Builder presignerBuilder = S3Presigner.builder()
                .region(Region.of(properties.getRegion()))
                .credentialsProvider(credentials)
                .serviceConfiguration(serviceConfiguration);
        if (properties.getEndpoint() != null && !properties.getEndpoint().isBlank()) {
            URI endpoint = URI.create(properties.getEndpoint());
            clientBuilder.endpointOverride(endpoint);
            presignerBuilder.endpointOverride(endpoint);
        }
        this.client = clientBuilder.build();
        this.presigner = presignerBuilder.build();
    }

    @Override
    public String store(byte[] content, String fileName, String contentType) {
        String safeName = fileName == null ? "document" : fileName.replaceAll("[^A-Za-z0-9._-]", "_");
        String storageKey = "private/documents/" + UUID.randomUUID() + "/" + safeName;
        PutObjectRequest request = PutObjectRequest.builder()
                .bucket(properties.getBucket())
                .key(storageKey)
                .contentType(contentType)
                .contentLength((long) content.length)
                .build();
        try {
            client.putObject(request, RequestBody.fromBytes(content));
            return storageKey;
        } catch (SdkException ex) {
            throw new DocumentStorageException(
                    "Private document storage is temporarily unavailable. Please try again.", ex);
        }
    }

    @Override
    public String generateSignedUrl(String storageKey, Duration ttl) {
        GetObjectRequest objectRequest = GetObjectRequest.builder()
                .bucket(properties.getBucket())
                .key(storageKey)
                .build();
        try {
            return presigner.presignGetObject(GetObjectPresignRequest.builder()
                            .signatureDuration(ttl)
                            .getObjectRequest(objectRequest)
                            .build())
                    .url().toExternalForm();
        } catch (SdkException ex) {
            throw new DocumentStorageException(
                    "The private document link could not be created. Please try again.", ex);
        }
    }

    @Override
    public void delete(String storageKey) {
        try {
            client.deleteObject(DeleteObjectRequest.builder()
                    .bucket(properties.getBucket())
                    .key(storageKey)
                    .build());
        } catch (SdkException ex) {
            throw new DocumentStorageException("The private document could not be deleted.", ex);
        }
    }

    @Override
    public void verifyReadWriteAccess() {
        String storageKey = "private/system/storage-probes/" + UUID.randomUUID() + ".txt";
        byte[] probe = "hi-pg storage probe\n".getBytes(StandardCharsets.UTF_8);
        PutObjectRequest put = PutObjectRequest.builder()
                .bucket(properties.getBucket())
                .key(storageKey)
                .contentType("text/plain")
                .contentLength((long) probe.length)
                .build();
        try {
            client.putObject(put, RequestBody.fromBytes(probe));
            client.deleteObject(DeleteObjectRequest.builder()
                    .bucket(properties.getBucket())
                    .key(storageKey)
                    .build());
        } catch (SdkException ex) {
            throw new DocumentStorageException(
                    "Private document storage credentials or bucket access are invalid.", ex);
        }
    }

    @PreDestroy
    void close() {
        presigner.close();
        client.close();
    }
}
