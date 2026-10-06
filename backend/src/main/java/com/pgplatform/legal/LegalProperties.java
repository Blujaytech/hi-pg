package com.pgplatform.legal;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.legal")
public record LegalProperties(String operatorName, String supportEmail, String postalAddress) {
}
