package com.pgplatform.notification.dto;

import java.util.List;

public record AdminMessageResponse(
        int recipients,
        int pushDevices,
        List<String> unresolvedRecipients
) { }
