package com.pgplatform.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

/**
 * Pure unit test (no Spring context, mirrors {@code UserEventBroadcasterTest}'s approach for a
 * dependency-free component) -- {@code @Value} fields are set directly via
 * {@link ReflectionTestUtils} since there's no property source to inject them from here.
 */
class RateLimitFilterTest {

    private RateLimitFilter filter;

    @BeforeEach
    void setUp() {
        filter = new RateLimitFilter(new ObjectMapper());
        ReflectionTestUtils.setField(filter, "windowSeconds", 60L);
        ReflectionTestUtils.setField(filter, "maxRequestsPerWindow", 3);
    }

    private MockHttpServletRequest authRequest(String path, String ip) {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", path);
        request.setRemoteAddr(ip);
        return request;
    }

    @Test
    void allowsRequestsUnderTheLimitAndBlocksOnceItsExceeded() throws Exception {
        FilterChain chain = Mockito.mock(FilterChain.class);

        for (int i = 0; i < 3; i++) {
            MockHttpServletRequest request = authRequest("/api/v1/auth/owner/login", "10.0.0.1");
            MockHttpServletResponse response = new MockHttpServletResponse();
            filter.doFilter(request, response, chain);
            assertThat(response.getStatus()).isEqualTo(200); // MockHttpServletResponse defaults to 200 when untouched
        }
        verify(chain, times(3)).doFilter(Mockito.any(), Mockito.any());

        MockHttpServletRequest fourthRequest = authRequest("/api/v1/auth/owner/login", "10.0.0.1");
        MockHttpServletResponse fourthResponse = new MockHttpServletResponse();
        filter.doFilter(fourthRequest, fourthResponse, chain);

        assertThat(fourthResponse.getStatus()).isEqualTo(429);
        assertThat(fourthResponse.getContentAsString()).contains("TOO_MANY_REQUESTS");
        verify(chain, times(3)).doFilter(Mockito.any(), Mockito.any()); // not called a 4th time
    }

    @Test
    void limitsAreTrackedPerIpNotGlobally() throws Exception {
        FilterChain chain = Mockito.mock(FilterChain.class);

        for (int i = 0; i < 3; i++) {
            filter.doFilter(authRequest("/api/v1/auth/owner/login", "10.0.0.2"), new MockHttpServletResponse(), chain);
        }
        // A different IP hitting the same path should not be affected by 10.0.0.2's usage.
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilter(authRequest("/api/v1/auth/owner/login", "10.0.0.3"), response, chain);

        assertThat(response.getStatus()).isEqualTo(200);
    }

    @Test
    void nonAuthPathsAreNeverRateLimited() throws Exception {
        FilterChain chain = Mockito.mock(FilterChain.class);

        for (int i = 0; i < 10; i++) {
            MockHttpServletResponse response = new MockHttpServletResponse();
            filter.doFilter(authRequest("/api/v1/public/pgs", "10.0.0.4"), response, chain);
            assertThat(response.getStatus()).isEqualTo(200);
        }
        verify(chain, times(10)).doFilter(Mockito.any(), Mockito.any());
    }

    @Test
    void honoursXForwardedForOverRemoteAddrForAttributingRequests() throws Exception {
        FilterChain chain = Mockito.mock(FilterChain.class);

        for (int i = 0; i < 3; i++) {
            MockHttpServletRequest request = authRequest("/api/v1/auth/owner/login", "127.0.0.1");
            request.addHeader("X-Forwarded-For", "203.0.113.9");
            filter.doFilter(request, new MockHttpServletResponse(), chain);
        }

        MockHttpServletRequest fourth = authRequest("/api/v1/auth/owner/login", "127.0.0.1");
        fourth.addHeader("X-Forwarded-For", "203.0.113.9");
        MockHttpServletResponse fourthResponse = new MockHttpServletResponse();
        filter.doFilter(fourth, fourthResponse, chain);

        assertThat(fourthResponse.getStatus()).isEqualTo(429);
    }
}
