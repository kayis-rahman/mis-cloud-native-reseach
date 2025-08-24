package com.sparkage.gateway.filter;

import org.junit.jupiter.api.Test;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.http.HttpStatus;
import org.springframework.mock.http.server.reactive.MockServerHttpRequest;
import org.springframework.mock.web.server.MockServerWebExchange;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.assertj.core.api.Assertions.assertThat;

class ApiKeyFilterAdditionalTest {

    private static class RecordingChain implements GatewayFilterChain {
        final AtomicBoolean invoked = new AtomicBoolean(false);
        @Override
        public Mono<Void> filter(org.springframework.web.server.ServerWebExchange exchange) {
            invoked.set(true);
            return Mono.empty();
        }
    }

    @Test
    void customHeaderNameIsRespected() {
        var filter = new ApiKeyFilter("secret", "X-Custom-Key", List.of());

        var okReq = MockServerHttpRequest.get("/api/test").header("X-Custom-Key", "secret").build();
        var okEx = MockServerWebExchange.from(okReq);
        var okChain = new RecordingChain();
        filter.filter(okEx, okChain).block();
        assertThat(okChain.invoked.get()).isTrue();
        assertThat(okEx.getResponse().getStatusCode()).isNull();

        var badReq = MockServerHttpRequest.get("/api/test").header("X-API-Key", "secret").build();
        var badEx = MockServerWebExchange.from(badReq);
        var badChain = new RecordingChain();
        filter.filter(badEx, badChain).block();
        assertThat(badChain.invoked.get()).isFalse();
        assertThat(badEx.getResponse().getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void allowlistUsesPrefixMatching() {
        var filter = new ApiKeyFilter("", "X-API-Key", List.of("/actuator/health"));

        // Starts with allowlisted path -> bypass security
        var req = MockServerHttpRequest.get("/actuator/healthcheck").build();
        var ex = MockServerWebExchange.from(req);
        var chain = new RecordingChain();
        filter.filter(ex, chain).block();
        assertThat(chain.invoked.get()).isTrue();
        assertThat(ex.getResponse().getStatusCode()).isNull();

        // Non-allowlisted path -> with no keys configured should be 401
        var req2 = MockServerHttpRequest.get("/not-allowed").build();
        var ex2 = MockServerWebExchange.from(req2);
        var chain2 = new RecordingChain();
        filter.filter(ex2, chain2).block();
        assertThat(chain2.invoked.get()).isFalse();
        assertThat(ex2.getResponse().getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void apiKeyFilterOrderRunsBeforeRateLimiter() {
        var apiKeyFilter = new ApiKeyFilter("key", "X-API-Key", List.of());
        var rateLimitFilter = new RateLimitFilter(10, 20, 10);
        assertThat(apiKeyFilter.getOrder()).isLessThan(rateLimitFilter.getOrder());
    }
}
