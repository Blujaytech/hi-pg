package com.pgplatform.payment;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RazorpayConfiguration {

    @Bean
    public RazorpayGateway razorpayGateway(RazorpayProperties properties) {
        return properties.isConfigured() ? new HttpRazorpayGateway(properties) : new StubRazorpayGateway();
    }
}
