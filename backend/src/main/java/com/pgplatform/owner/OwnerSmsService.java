package com.pgplatform.owner;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

@Service
public class OwnerSmsService {
    private static final Logger log = LoggerFactory.getLogger(OwnerSmsService.class);

    private final OwnerSmsMessageRepository messageRepository;
    private final ObjectMapper objectMapper;
    private final RestClient restClient = RestClient.create();

    @Value("${app.sms.enabled:false}")
    private boolean enabled;
    @Value("${app.sms.provider:TWILIO}")
    private String provider;
    @Value("${app.sms.twilio.account-sid:}")
    private String accountSid;
    @Value("${app.sms.twilio.auth-token:}")
    private String authToken;
    @Value("${app.sms.twilio.from-number:}")
    private String fromNumber;
    @Value("${app.sms.claim-url:https://hipg.app/owner}")
    private String claimUrl;

    public OwnerSmsService(OwnerSmsMessageRepository messageRepository, ObjectMapper objectMapper) {
        this.messageRepository = messageRepository;
        this.objectMapper = objectMapper;
    }

    public String claimUrl() { return claimUrl; }

    /** Sends at most one successful SMS for a business event and keeps an auditable result. */
    @Transactional
    public OwnerSmsResult sendOnce(Pg pg, String eventKey, String mobile, String text) {
        OwnerSmsMessage audit = messageRepository.findByPgIdAndEventKeyAndDeletedAtIsNull(pg.getId(), eventKey)
                .orElseGet(OwnerSmsMessage::new);
        if (audit.getStatus() == OwnerSmsStatus.SENT) {
            return new OwnerSmsResult(OwnerSmsStatus.SENT, audit.getProviderMessageId(), null);
        }
        audit.setPg(pg);
        audit.setEventKey(eventKey);
        audit.setRecipientMobile(mobile);
        audit.setMessageText(text);
        audit.setProvider(provider == null ? "UNCONFIGURED" : provider.trim().toUpperCase());

        OwnerSmsResult result;
        if (!enabled) {
            result = new OwnerSmsResult(OwnerSmsStatus.SKIPPED, null, "SMS provider is disabled");
        } else if (!"TWILIO".equalsIgnoreCase(provider)) {
            result = new OwnerSmsResult(OwnerSmsStatus.FAILED, null, "Unsupported SMS provider: " + provider);
        } else if (isBlank(accountSid) || isBlank(authToken) || isBlank(fromNumber)) {
            result = new OwnerSmsResult(OwnerSmsStatus.FAILED, null, "Twilio credentials are incomplete");
        } else {
            result = sendTwilio(mobile, text);
        }
        audit.setStatus(result.status());
        audit.setProviderMessageId(result.providerMessageId());
        audit.setFailureReason(limit(result.failureReason(), 2000));
        messageRepository.save(audit);
        return result;
    }

    private OwnerSmsResult sendTwilio(String mobile, String text) {
        try {
            MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
            form.add("To", mobile);
            form.add("From", fromNumber);
            form.add("Body", text);
            String body = restClient.post()
                    .uri("https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json", accountSid)
                    .headers(headers -> headers.setBasicAuth(accountSid, authToken))
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(form)
                    .retrieve()
                    .body(String.class);
            JsonNode json = objectMapper.readTree(body == null ? "{}" : body);
            String sid = json.path("sid").asText(null);
            return new OwnerSmsResult(OwnerSmsStatus.SENT, sid, null);
        } catch (Exception error) {
            log.warn("Owner SMS delivery failed for {}: {}", mask(mobile), error.getMessage());
            return new OwnerSmsResult(OwnerSmsStatus.FAILED, null, error.getMessage());
        }
    }

    private static boolean isBlank(String value) { return value == null || value.isBlank(); }
    private static String limit(String value, int max) {
        if (value == null) return null;
        return value.length() <= max ? value : value.substring(0, max);
    }
    private static String mask(String mobile) {
        return mobile == null || mobile.length() < 4 ? "****" : "****" + mobile.substring(mobile.length() - 4);
    }
}
