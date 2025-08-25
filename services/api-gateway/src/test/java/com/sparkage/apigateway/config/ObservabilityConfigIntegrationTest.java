package com.sparkage.apigateway.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.context.annotation.Bean;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.mock.http.server.reactive.MockServerHttpRequest;
import org.springframework.mock.web.server.MockServerWebExchange;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;
import reactor.test.StepVerifier;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ObservabilityConfigIntegrationTest {

    private MeterRegistry meterRegistry;
    private ObservabilityConfig.CustomMetricsFilter metricsFilter;
    private GatewayFilterChain filterChain;

    @BeforeEach
    void setUp() {
        meterRegistry = new SimpleMeterRegistry();
        metricsFilter = new ObservabilityConfig.CustomMetricsFilter(meterRegistry);
        filterChain = mock(GatewayFilterChain.class);
    }

    @Test
    void shouldCollectMetricsForSuccessfulRequests() {
        // Given
        ServerWebExchange exchange = createMockExchange("/test/success", HttpMethod.GET, HttpStatus.OK);
        when(filterChain.filter(exchange)).thenReturn(Mono.empty());

        // When
        StepVerifier.create(metricsFilter.filter(exchange, filterChain))
                .verifyComplete();

        // Then
        Timer timer = meterRegistry.find("gateway_request_duration").timer();
        assertThat(timer).isNotNull();
        assertThat(timer.count()).isEqualTo(1);

        Counter counter = meterRegistry.find("gateway_requests_total")
                .tag("route", "/test/success")
                .tag("method", "GET")
                .tag("status", "200")
                .counter();
        assertThat(counter).isNotNull();
        assertThat(counter.count()).isEqualTo(1.0);
    }

    @Test
    void shouldCollectMetricsForErrorRequests() {
        // Given
        ServerWebExchange exchange = createMockExchange("/test/error", HttpMethod.GET, HttpStatus.INTERNAL_SERVER_ERROR);
        when(filterChain.filter(exchange)).thenReturn(Mono.empty());

        // When
        StepVerifier.create(metricsFilter.filter(exchange, filterChain))
                .verifyComplete();

        // Then
        Timer timer = meterRegistry.find("gateway_request_duration").timer();
        assertThat(timer).isNotNull();
        assertThat(timer.count()).isEqualTo(1);

        Counter counter = meterRegistry.find("gateway_requests_total")
                .tag("route", "/test/error")
                .tag("method", "GET")
                .tag("status", "500")
                .counter();
        assertThat(counter).isNotNull();
        assertThat(counter.count()).isEqualTo(1.0);
    }

    @Test
    void shouldCollectMetricsForNotFoundRequests() {
        // Given
        ServerWebExchange exchange = createMockExchange("/nonexistent/path", HttpMethod.GET, HttpStatus.NOT_FOUND);
        when(filterChain.filter(exchange)).thenReturn(Mono.empty());

        // When
        StepVerifier.create(metricsFilter.filter(exchange, filterChain))
                .verifyComplete();

        // Then
        Timer timer = meterRegistry.find("gateway_request_duration").timer();
        assertThat(timer).isNotNull();
        assertThat(timer.count()).isEqualTo(1);

        Counter counter = meterRegistry.find("gateway_requests_total")
                .tag("route", "/nonexistent/path")
                .tag("method", "GET")
                .tag("status", "404")
                .counter();
        assertThat(counter).isNotNull();
        assertThat(counter.count()).isEqualTo(1.0);
    }

    @Test
    void shouldCollectMetricsForDifferentHttpMethods() {
        // Given
        ServerWebExchange exchange = createMockExchange("/test/post", HttpMethod.POST, HttpStatus.OK);
        when(filterChain.filter(exchange)).thenReturn(Mono.empty());

        // When
        StepVerifier.create(metricsFilter.filter(exchange, filterChain))
                .verifyComplete();

        // Then
        Counter counter = meterRegistry.find("gateway_requests_total")
                .tag("route", "/test/post")
                .tag("method", "POST")
                .tag("status", "200")
                .counter();
        assertThat(counter).isNotNull();
        assertThat(counter.count()).isEqualTo(1.0);
    }

    @Test
    void shouldAccumulateMetricsOverMultipleRequests() {
        // Given
        int requestCount = 3;
        ServerWebExchange exchange = createMockExchange("/test/multiple", HttpMethod.GET, HttpStatus.OK);
        when(filterChain.filter(exchange)).thenReturn(Mono.empty());

        // When
        for (int i = 0; i < requestCount; i++) {
            StepVerifier.create(metricsFilter.filter(exchange, filterChain))
                    .verifyComplete();
        }

        // Then
        Timer timer = meterRegistry.find("gateway_request_duration").timer();
        assertThat(timer).isNotNull();
        assertThat(timer.count()).isEqualTo(requestCount);

        Counter counter = meterRegistry.find("gateway_requests_total")
                .tag("route", "/test/multiple")
                .tag("method", "GET")
                .tag("status", "200")
                .counter();
        assertThat(counter).isNotNull();
        assertThat(counter.count()).isEqualTo(requestCount);
    }

    @Test
    void shouldTrackDifferentRoutesIndependently() {
        // Given
        ServerWebExchange exchange1 = createMockExchange("/test/route1", HttpMethod.GET, HttpStatus.OK);
        ServerWebExchange exchange2 = createMockExchange("/test/route2", HttpMethod.GET, HttpStatus.OK);
        when(filterChain.filter(exchange1)).thenReturn(Mono.empty());
        when(filterChain.filter(exchange2)).thenReturn(Mono.empty());

        // When
        StepVerifier.create(metricsFilter.filter(exchange1, filterChain)).verifyComplete();
        StepVerifier.create(metricsFilter.filter(exchange1, filterChain)).verifyComplete();
        StepVerifier.create(metricsFilter.filter(exchange2, filterChain)).verifyComplete();

        // Then
        Counter counter1 = meterRegistry.find("gateway_requests_total")
                .tag("route", "/test/route1")
                .tag("method", "GET")
                .tag("status", "200")
                .counter();
        assertThat(counter1).isNotNull();
        assertThat(counter1.count()).isEqualTo(2.0);

        Counter counter2 = meterRegistry.find("gateway_requests_total")
                .tag("route", "/test/route2")
                .tag("method", "GET")
                .tag("status", "200")
                .counter();
        assertThat(counter2).isNotNull();
        assertThat(counter2.count()).isEqualTo(1.0);
    }

    @Test
    void meterRegistryBeanShouldBeAvailable() {
        // Given
        ObservabilityConfig config = new ObservabilityConfig();

        // When
        MeterRegistry registry = config.meterRegistry();

        // Then
        assertThat(registry).isNotNull();
        assertThat(registry).isInstanceOf(SimpleMeterRegistry.class);
    }

    @Test
    void customMetricsFilterShouldBeCreated() {
        // Given
        ObservabilityConfig config = new ObservabilityConfig();
        MeterRegistry registry = new SimpleMeterRegistry();

        // When
        var filter = config.customMetricsFilter(registry);

        // Then
        assertThat(filter).isNotNull();
        assertThat(filter).isInstanceOf(ObservabilityConfig.CustomMetricsFilter.class);
    }

    private ServerWebExchange createMockExchange(String path, HttpMethod method, HttpStatus status) {
        MockServerHttpRequest request = MockServerHttpRequest.method(method, path).build();
        MockServerWebExchange exchange = MockServerWebExchange.from(request);
        exchange.getResponse().setStatusCode(status);
        return exchange;
    }

    @TestConfiguration
    static class TestConfig {
        @Bean
        public MeterRegistry testMeterRegistry() {
            return new SimpleMeterRegistry();
        }
    }
}
