package com.sparkage.apigateway.performance;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.mock.http.server.reactive.MockServerHttpRequest;
import org.springframework.mock.web.server.MockServerWebExchange;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;
import reactor.test.StepVerifier;

import com.sparkage.apigateway.config.ObservabilityConfig;

import java.time.Duration;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ObservabilityPerformanceTest {

    private final MeterRegistry meterRegistry = new SimpleMeterRegistry();
    private final GatewayFilterChain filterChain = mock(GatewayFilterChain.class);

    @Test
    @Timeout(value = 5, unit = TimeUnit.SECONDS)
    void observabilityFilterShouldNotSignificantlyImpactPerformance() {
        // Given
        ObservabilityConfig.CustomMetricsFilter filter =
            new ObservabilityConfig.CustomMetricsFilter(meterRegistry);

        when(filterChain.filter(any(ServerWebExchange.class)))
            .thenReturn(Mono.delay(Duration.ofMillis(1)).then()); // Simulate minimal processing time

        // When - Process many requests
        long startTime = System.currentTimeMillis();
        int requestCount = 1000;

        for (int i = 0; i < requestCount; i++) {
            MockServerHttpRequest request = MockServerHttpRequest
                .method(HttpMethod.GET, "/api/test/" + i)
                .build();

            ServerWebExchange exchange = MockServerWebExchange.from(request);
            exchange.getResponse().setStatusCode(HttpStatus.OK);

            StepVerifier.create(filter.filter(exchange, filterChain))
                .verifyComplete();
        }

        long endTime = System.currentTimeMillis();
        long totalTime = endTime - startTime;

        // Then - Verify performance is acceptable
        double averageTimePerRequest = (double) totalTime / requestCount;
        assertThat(averageTimePerRequest).isLessThan(5.0); // Less than 5ms per request on average

        // Verify all metrics were collected
        assertThat(meterRegistry.find("gateway_request_duration").timer().count())
            .isEqualTo(requestCount);
    }

    @Test
    @Timeout(value = 2, unit = TimeUnit.SECONDS)
    void metricCreationShouldBeEfficient() {
        // Given
        ObservabilityConfig.CustomMetricsFilter filter =
            new ObservabilityConfig.CustomMetricsFilter(meterRegistry);

        when(filterChain.filter(any(ServerWebExchange.class)))
            .thenReturn(Mono.empty());

        // When - Create many different metric combinations
        long startTime = System.currentTimeMillis();

        for (int i = 0; i < 100; i++) {
            for (String method : new String[]{"GET", "POST", "PUT", "DELETE"}) {
                for (String status : new String[]{"200", "404", "500"}) {
                    MockServerHttpRequest request = MockServerHttpRequest
                        .method(HttpMethod.valueOf(method), "/api/route/" + i)
                        .build();

                    ServerWebExchange exchange = MockServerWebExchange.from(request);
                    exchange.getResponse().setStatusCode(HttpStatus.valueOf(Integer.parseInt(status)));

                    StepVerifier.create(filter.filter(exchange, filterChain))
                        .verifyComplete();
                }
            }
        }

        long endTime = System.currentTimeMillis();
        long totalTime = endTime - startTime;

        // Then - Should complete within reasonable time
        assertThat(totalTime).isLessThan(2000); // Less than 2 seconds for 1200 requests

        // Verify metrics registry has expected number of meters
        assertThat(meterRegistry.getMeters().size()).isGreaterThan(0);
    }

    @Test
    void memoryShouldNotGrowExcessivelyWithManyUniqueRoutes() {
        // Given
        ObservabilityConfig.CustomMetricsFilter filter =
            new ObservabilityConfig.CustomMetricsFilter(meterRegistry);

        when(filterChain.filter(any(ServerWebExchange.class)))
            .thenReturn(Mono.empty());

        Runtime runtime = Runtime.getRuntime();
        runtime.gc(); // Force garbage collection before test
        long initialMemory = runtime.totalMemory() - runtime.freeMemory();

        // When - Create many unique routes
        for (int i = 0; i < 1000; i++) {
            MockServerHttpRequest request = MockServerHttpRequest
                .method(HttpMethod.GET, "/api/unique/route/" + i)
                .build();

            ServerWebExchange exchange = MockServerWebExchange.from(request);
            exchange.getResponse().setStatusCode(HttpStatus.OK);

            StepVerifier.create(filter.filter(exchange, filterChain))
                .verifyComplete();
        }

        runtime.gc(); // Force garbage collection after test
        long finalMemory = runtime.totalMemory() - runtime.freeMemory();
        long memoryIncrease = finalMemory - initialMemory;

        // Then - Memory increase should be reasonable (less than 50MB)
        assertThat(memoryIncrease).isLessThan(50 * 1024 * 1024);

        // Verify all metrics were created
        assertThat(meterRegistry.find("gateway_request_duration").timer().count())
            .isEqualTo(1000);
    }

    @Test
    @Timeout(value = 3, unit = TimeUnit.SECONDS)
    void concurrentRequestsShouldBeHandledEfficiently() {
        // Given
        ObservabilityConfig.CustomMetricsFilter filter =
            new ObservabilityConfig.CustomMetricsFilter(meterRegistry);

        when(filterChain.filter(any(ServerWebExchange.class)))
            .thenReturn(Mono.delay(Duration.ofMillis(10)).then());

        // When - Process concurrent requests
        Mono<Void>[] requests = new Mono[100];

        for (int i = 0; i < 100; i++) {
            final int requestId = i;
            requests[i] = Mono.fromRunnable(() -> {
                MockServerHttpRequest request = MockServerHttpRequest
                    .method(HttpMethod.GET, "/api/concurrent/" + requestId)
                    .build();

                ServerWebExchange exchange = MockServerWebExchange.from(request);
                exchange.getResponse().setStatusCode(HttpStatus.OK);

                StepVerifier.create(filter.filter(exchange, filterChain))
                    .verifyComplete();
            });
        }

        // Then - All requests should complete without issues
        StepVerifier.create(Mono.when(requests))
            .verifyComplete();

        // Verify metrics were collected for all requests
        assertThat(meterRegistry.find("gateway_request_duration").timer().count())
            .isEqualTo(100);
    }
}
