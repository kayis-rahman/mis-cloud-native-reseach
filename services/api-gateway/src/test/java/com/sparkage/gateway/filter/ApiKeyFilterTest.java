package com.sparkage.gateway.filter;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.http.HttpStatus;
import org.springframework.mock.http.server.reactive.MockServerHttpRequest;
import org.springframework.mock.web.server.MockServerWebExchange;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.assertj.core.api.Assertions.assertThat;

class ApiKeyFilterTest {

    private ApiKeyFilter filterWithKeys;
    private ApiKeyFilter filterWithoutKeys;

    @BeforeEach
    void setup() {
        filterWithKeys = new ApiKeyFilter("k1,k2", "X-API-Key", List.of("/actuator/health", "/actuator/info"));
        filterWithoutKeys = new ApiKeyFilter("", "X-API-Key", List.of("/actuator/health"));
    }

    private static class RecordingChain implements GatewayFilterChain {
        final AtomicBoolean invoked = new AtomicBoolean(false);
        @Override
        public Mono<Void> filter(org.springframework.web.server.ServerWebExchange exchange) {
            invoked.set(true);
            return Mono.empty();
        }
    }

    @Test
    void allowlistPathBypassesSecurity() {
        var request = MockServerHttpRequest.get("/actuator/health").build();
        var exchange = MockServerWebExchange.from(request);
        var chain = new RecordingChain();

        filterWithoutKeys.filter(exchange, chain).block();

        assertThat(chain.invoked.get()).isTrue();
        // Should not set unauthorized
        assertThat(exchange.getResponse().getStatusCode()).isNull();
    }

    @Test
    void noKeysConfiguredRejectsWith401() {
        var request = MockServerHttpRequest.get("/api/anything").build();
        var exchange = MockServerWebExchange.from(request);
        var chain = new RecordingChain();

        filterWithoutKeys.filter(exchange, chain).block();

        assertThat(chain.invoked.get()).isFalse();
        assertThat(exchange.getResponse().getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void missingOrWrongKeyIsForbidden() {
        var req1 = MockServerHttpRequest.get("/api/test").build();
        var ex1 = MockServerWebExchange.from(req1);
        var chain1 = new RecordingChain();
        filterWithKeys.filter(ex1, chain1).block();
        assertThat(chain1.invoked.get()).isFalse();
        assertThat(ex1.getResponse().getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        var req2 = MockServerHttpRequest.get("/api/test").header("X-API-Key", "bad").build();
        var ex2 = MockServerWebExchange.from(req2);
        var chain2 = new RecordingChain();
        filterWithKeys.filter(ex2, chain2).block();
        assertThat(chain2.invoked.get()).isFalse();
        assertThat(ex2.getResponse().getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void validKeyProceeds() {
        var request = MockServerHttpRequest.get("/api/test").header("X-API-Key", "k1").build();
        var exchange = MockServerWebExchange.from(request);
        var chain = new RecordingChain();

        filterWithKeys.filter(exchange, chain).block();

        assertThat(chain.invoked.get()).isTrue();
        // Filter should not set a status (routing layer would)
        assertThat(exchange.getResponse().getStatusCode()).isNull();
    }
}
