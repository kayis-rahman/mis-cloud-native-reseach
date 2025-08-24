package com.sparkage.gateway.filter;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.http.HttpStatus;
import org.springframework.mock.http.server.reactive.MockServerHttpRequest;
import org.springframework.mock.web.server.MockServerWebExchange;
import reactor.core.publisher.Mono;

import java.util.concurrent.atomic.AtomicBoolean;

import static org.assertj.core.api.Assertions.assertThat;

class RateLimitFilterTest {

    private RateLimitFilter filter;

    @BeforeEach
    void setup() {
        // Set replenishRate=1/sec, burstCapacity=2, cache expiry irrelevant for unit
        filter = new RateLimitFilter(1, 2, 10);
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
    void allowsWithinBurstAndBlocksAfter() {
        var chain = new RecordingChain();

        var req1 = MockServerHttpRequest.get("/path").header("X-API-Key", "k").build();
        var ex1 = MockServerWebExchange.from(req1);
        filter.filter(ex1, chain).block();
        assertThat(ex1.getResponse().getStatusCode()).isNull();
        assertThat(chain.invoked.get()).isTrue();

        // second within burst
        var chain2 = new RecordingChain();
        var req2 = MockServerHttpRequest.get("/path").header("X-API-Key", "k").build();
        var ex2 = MockServerWebExchange.from(req2);
        filter.filter(ex2, chain2).block();
        assertThat(ex2.getResponse().getStatusCode()).isNull();
        assertThat(chain2.invoked.get()).isTrue();

        // third should exceed burst (burst=2, replenish=1/sec); if within same second, expect 429
        var chain3 = new RecordingChain();
        var req3 = MockServerHttpRequest.get("/path").header("X-API-Key", "k").build();
        var ex3 = MockServerWebExchange.from(req3);
        filter.filter(ex3, chain3).block();
        assertThat(chain3.invoked.get()).isFalse();
        assertThat(ex3.getResponse().getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
    }
}
