package com.pgplatform.document;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.storage.s3")
public class S3StorageProperties {
    private boolean enabled;
    private String endpoint = "";
    private String region = "ap-south-1";
    private String bucket = "";
    private String accessKey = "";
    private String secretKey = "";
    private boolean pathStyleAccess;

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public String getEndpoint() { return endpoint; }
    public void setEndpoint(String endpoint) { this.endpoint = endpoint; }
    public String getRegion() { return region; }
    public void setRegion(String region) { this.region = region; }
    public String getBucket() { return bucket; }
    public void setBucket(String bucket) { this.bucket = bucket; }
    public String getAccessKey() { return accessKey; }
    public void setAccessKey(String accessKey) { this.accessKey = accessKey; }
    public String getSecretKey() { return secretKey; }
    public void setSecretKey(String secretKey) { this.secretKey = secretKey; }
    public boolean isPathStyleAccess() { return pathStyleAccess; }
    public void setPathStyleAccess(boolean pathStyleAccess) { this.pathStyleAccess = pathStyleAccess; }

    void validate() {
        if (blank(region) || blank(bucket) || blank(accessKey) || blank(secretKey)) {
            throw new IllegalStateException(
                    "S3 storage is enabled but region, bucket, access key, or secret key is missing");
        }
    }

    private boolean blank(String value) {
        return value == null || value.isBlank();
    }
}
