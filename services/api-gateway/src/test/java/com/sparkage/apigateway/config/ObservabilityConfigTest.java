package com.sparkage.apigateway.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.mock.http.server.reactive.MockServerHttpRequest;
import org.springframework.mock.web.server.MockServerWebExchange;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;
import reactor.test.StepVerifier;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ObservabilityConfigTest {

    private ObservabilityConfig observabilityConfig;
    private MeterRegistry meterRegistry;

    @Mock
    private GatewayFilterChain filterChain;

    @BeforeEach
    void setUp() {
        observabilityConfig = new ObservabilityConfig();
        meterRegistry = new SimpleMeterRegistry();
    }

    @Test
    void shouldCreateMeterRegistryBean() {
        // When
        MeterRegistry result = observabilityConfig.meterRegistry();

        // Then
        assertThat(result).isNotNull();
        assertThat(result).isInstanceOf(SimpleMeterRegistry.class);
    }

    @Test
    void shouldCreateCustomMetricsFilterBean() {
        // When
        GlobalFilter filter = observabilityConfig.customMetricsFilter(meterRegistry);

        // Then
        assertThat(filter).isNotNull();
        assertThat(filter).isInstanceOf(ObservabilityConfig.CustomMetricsFilter.class);
    }

    @Test
    void customMetricsFilterShouldHaveHighestPrecedence() {
        // Given
        ObservabilityConfig.CustomMetricsFilter filter =
            new ObservabilityConfig.CustomMetricsFilter(meterRegistry);

        // When
        int order = filter.getOrder();

        // Then
        assertThat(order).isEqualTo(Integer.MIN_VALUE); // HIGHEST_PRECEDENCE
    }

    @Test
    void customMetricsFilterShouldRecordMetrics() {
        // Given
        ObservabilityConfig.CustomMetricsFilter filter =
            new ObservabilityConfig.CustomMetricsFilter(meterRegistry);

        MockServerHttpRequest request = MockServerHttpRequest
            .method(HttpMethod.GET, "/api/products/1")
            .build();

        ServerWebExchange exchange = MockServerWebExchange.from(request);
        exchange.getResponse().setStatusCode(HttpStatus.OK);

        when(filterChain.filter(any(ServerWebExchange.class)))
            .thenReturn(Mono.empty());

        // When
        StepVerifier.create(filter.filter(exchange, filterChain))
            .verifyComplete();

        // Then
        // Verify that timer metric was created
        Timer timer = meterRegistry.find("gateway_request_duration").timer();
        assertThat(timer).isNotNull();
        assertThat(timer.count()).isEqualTo(1);

        // Verify that counter metric was created with proper tags
        Counter counter = meterRegistry.find("gateway_requests_total")
            .tag("route", "/api/products/1")
            .tag("method", "GET")
            .tag("status", "200")
            .counter();
        assertThat(counter).isNotNull();
        assertThat(counter.count()).isEqualTo(1.0);
    }

    @Test
    void customMetricsFilterShouldHandleNullStatusCode() {
        // Given
        ObservabilityConfig.CustomMetricsFilter filter =
            new ObservabilityConfig.CustomMetricsFilter(meterRegistry);

        MockServerHttpRequest request = MockServerHttpRequest
            .method(HttpMethod.POST, "/api/cart/add")
            .build();

        ServerWebExchange exchange = MockServerWebExchange.from(request);
        // Don't set status code - it will be null

        when(filterChain.filter(any(ServerWebExchange.class)))
            .thenReturn(Mono.empty());

        // When
        StepVerifier.create(filter.filter(exchange, filterChain))
            .verifyComplete();

        // Then
        Counter counter = meterRegistry.find("gateway_requests_total")
            .tag("route", "/api/cart/add")
            .tag("method", "POST")
            .tag("status", "0")
            .counter();
        assertThat(counter).isNotNull();
        assertThat(counter.count()).isEqualTo(1.0);
    }

    @Test
    void customMetricsFilterShouldHandleErrorResponses() {
        // Given
        ObservabilityConfig.CustomMetricsFilter filter =
            new ObservabilityConfig.CustomMetricsFilter(meterRegistry);

        MockServerHttpRequest request = MockServerHttpRequest
            .method(HttpMethod.DELETE, "/api/orders/123")
            .build();

        ServerWebExchange exchange = MockServerWebExchange.from(request);
        exchange.getResponse().setStatusCode(HttpStatus.NOT_FOUND);

        when(filterChain.filter(any(ServerWebExchange.class)))
            .thenReturn(Mono.empty());

        // When
        StepVerifier.create(filter.filter(exchange, filterChain))
            .verifyComplete();

        // Then
        Counter counter = meterRegistry.find("gateway_requests_total")
            .tag("route", "/api/orders/123")
            .tag("method", "DELETE")
            .tag("status", "404")
            .counter();
        assertThat(counter).isNotNull();
        assertThat(counter.count()).isEqualTo(1.0);
    }

    @Test
    void customMetricsFilterShouldPropagateFilterChainExceptions() {
        // Given
        ObservabilityConfig.CustomMetricsFilter filter =
            new ObservabilityConfig.CustomMetricsFilter(meterRegistry);

        MockServerHttpRequest request = MockServerHttpRequest
            .method(HttpMethod.GET, "/api/test")
            .build();

        ServerWebExchange exchange = MockServerWebExchange.from(request);
        RuntimeException expectedException = new RuntimeException("Filter chain error");

        when(filterChain.filter(any(ServerWebExchange.class)))
            .thenReturn(Mono.error(expectedException));

        // When & Then
        StepVerifier.create(filter.filter(exchange, filterChain))
            .expectError(RuntimeException.class)
            .verify();

        // Verify metrics are still recorded even on error
        Timer timer = meterRegistry.find("gateway_request_duration").timer();
        assertThat(timer).isNotNull();
        assertThat(timer.count()).isEqualTo(1);
    }

    @Test
    void multipleRequestsShouldAccumulateMetrics() {
        // Given
        ObservabilityConfig.CustomMetricsFilter filter =
            new ObservabilityConfig.CustomMetricsFilter(meterRegistry);

        when(filterChain.filter(any(ServerWebExchange.class)))
            .thenReturn(Mono.empty());

        // When - Make multiple requests
        for (int i = 0; i < 5; i++) {
            MockServerHttpRequest request = MockServerHttpRequest
                .method(HttpMethod.GET, "/api/products")
                .build();

            ServerWebExchange exchange = MockServerWebExchange.from(request);
            exchange.getResponse().setStatusCode(HttpStatus.OK);

            StepVerifier.create(filter.filter(exchange, filterChain))
                .verifyComplete();
        }

        // Then
        Timer timer = meterRegistry.find("gateway_request_duration").timer();
        assertThat(timer).isNotNull();
        assertThat(timer.count()).isEqualTo(5);

        Counter counter = meterRegistry.find("gateway_requests_total")
            .tag("route", "/api/products")
            .tag("method", "GET")
            .tag("status", "200")
            .counter();
        assertThat(counter).isNotNull();
        assertThat(counter.count()).isEqualTo(5.0);
    }
}
