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

class RateLimitFilterAdditionalTest {

    private RateLimitFilter filter;

    private static class RecordingChain implements GatewayFilterChain {
        final AtomicBoolean invoked = new AtomicBoolean(false);
        @Override
        public Mono<Void> filter(org.springframework.web.server.ServerWebExchange exchange) {
            invoked.set(true);
            return Mono.empty();
        }
    }

    @BeforeEach
    void setup() {
        // Low burst to make assertions deterministic within a single window
        filter = new RateLimitFilter(1, 2, 10);
    }

    @Test
    void perApiKeyIsolation() {
        // Two requests with key A consume burst but do not affect key B
        var chainA1 = new RecordingChain();
        var reqA1 = MockServerHttpRequest.get("/r").header("X-API-Key", "A").build();
        var exA1 = MockServerWebExchange.from(reqA1);
        filter.filter(exA1, chainA1).block();
        assertThat(chainA1.invoked.get()).isTrue();

        var chainA2 = new RecordingChain();
        var reqA2 = MockServerHttpRequest.get("/r").header("X-API-Key", "A").build();
        var exA2 = MockServerWebExchange.from(reqA2);
        filter.filter(exA2, chainA2).block();
        assertThat(chainA2.invoked.get()).isTrue();

        // Third with A should be blocked
        var chainA3 = new RecordingChain();
        var reqA3 = MockServerHttpRequest.get("/r").header("X-API-Key", "A").build();
        var exA3 = MockServerWebExchange.from(reqA3);
        filter.filter(exA3, chainA3).block();
        assertThat(chainA3.invoked.get()).isFalse();
        assertThat(exA3.getResponse().getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);

        // Now key B should still be allowed within its own burst
        var chainB1 = new RecordingChain();
        var reqB1 = MockServerHttpRequest.get("/r").header("X-API-Key", "B").build();
        var exB1 = MockServerWebExchange.from(reqB1);
        filter.filter(exB1, chainB1).block();
        assertThat(chainB1.invoked.get()).isTrue();
        assertThat(exB1.getResponse().getStatusCode()).isNull();
    }

    @Test
    void usesXForwardedForWhenNoApiKey() {
        // Same XFF should be limited together
        var chain1 = new RecordingChain();
        var req1 = MockServerHttpRequest.get("/r").header("X-Forwarded-For", "10.0.0.1").build();
        var ex1 = MockServerWebExchange.from(req1);
        filter.filter(ex1, chain1).block();
        assertThat(chain1.invoked.get()).isTrue();

        var chain2 = new RecordingChain();
        var req2 = MockServerHttpRequest.get("/r").header("X-Forwarded-For", "10.0.0.1").build();
        var ex2 = MockServerWebExchange.from(req2);
        filter.filter(ex2, chain2).block();
        assertThat(chain2.invoked.get()).isTrue();

        var chain3 = new RecordingChain();
        var req3 = MockServerHttpRequest.get("/r").header("X-Forwarded-For", "10.0.0.1").build();
        var ex3 = MockServerWebExchange.from(req3);
        filter.filter(ex3, chain3).block();
        assertThat(chain3.invoked.get()).isFalse();
        assertThat(ex3.getResponse().getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);

        // Different XFF should have a fresh counter
        var chainOther = new RecordingChain();
        var reqOther = MockServerHttpRequest.get("/r").header("X-Forwarded-For", "10.0.0.2").build();
        var exOther = MockServerWebExchange.from(reqOther);
        filter.filter(exOther, chainOther).block();
        assertThat(chainOther.invoked.get()).isTrue();
        assertThat(exOther.getResponse().getStatusCode()).isNull();
    }

    @Test
    void fallsBackToRemoteAddressGroupingWhenNoHeaders() {
        // With MockServer, remote address may be null; in that case, key becomes the same ("ip:null")
        // causing them to share the same window, which we can still assert on deterministically.
        var c1 = new RecordingChain();
        var r1 = MockServerHttpRequest.get("/r").build();
        var e1 = MockServerWebExchange.from(r1);
        filter.filter(e1, c1).block();
        assertThat(c1.invoked.get()).isTrue();

        var c2 = new RecordingChain();
        var r2 = MockServerHttpRequest.get("/r").build();
        var e2 = MockServerWebExchange.from(r2);
        filter.filter(e2, c2).block();
        assertThat(c2.invoked.get()).isTrue();

        var c3 = new RecordingChain();
        var r3 = MockServerHttpRequest.get("/r").build();
        var e3 = MockServerWebExchange.from(r3);
        filter.filter(e3, c3).block();
        assertThat(c3.invoked.get()).isFalse();
        assertThat(e3.getResponse().getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
    }
}
