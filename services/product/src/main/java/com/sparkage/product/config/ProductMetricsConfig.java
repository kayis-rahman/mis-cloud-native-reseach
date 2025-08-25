package com.sparkage.product.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.Gauge;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.context.annotation.Bean;

// Updated to Jakarta namespace for Spring Boot 3+
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.concurrent.atomic.AtomicInteger;

@Configuration
public class ProductMetricsConfig {

    @Autowired
    private MeterRegistry meterRegistry;

    private final AtomicInteger activeRequests = new AtomicInteger(0);

    @Bean
    public OncePerRequestFilter productMetricsFilter() {
        return new ProductMetricsFilter();
    }

    public class ProductMetricsFilter extends OncePerRequestFilter {

        // Keep a base timer name; counters with dynamic tags will be resolved per-request
        private final String requestCounterName = "product_service_requests_total";
        private final String requestTimerName = "product_service_request_duration_seconds";
        private final String productOperationCounterName = "product_operations_total";

        public ProductMetricsFilter() {
            // Register gauge for active requests (object + value function)
            Gauge.builder("product_service_active_requests", activeRequests, AtomicInteger::get)
                    .description("Active requests to product service")
                    .register(meterRegistry);
        }

        @Override
        protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                      FilterChain filterChain) throws ServletException, IOException {

            Timer.Sample sample = Timer.start(meterRegistry);
            activeRequests.incrementAndGet();

            try {
                filterChain.doFilter(request, response);
            } finally {
                String method = request.getMethod();
                String uri = request.getRequestURI();
                String status = String.valueOf(response.getStatus());

                // Record timer with tags
                sample.stop(meterRegistry.timer(requestTimerName, "method", method, "uri", uri, "status", status));

                // Increment request counter with tags
                meterRegistry.counter(requestCounterName, "method", method, "uri", uri, "status", status).increment();

                // Track specific product operations
                if (uri.contains("/products")) {
                    String operation = getOperationType(method, uri);
                    meterRegistry.counter(productOperationCounterName, "operation", operation).increment();
                }

                activeRequests.decrementAndGet();
            }
        }

        private String getOperationType(String method, String uri) {
            if (method.equals("GET") && uri.matches(".*/products/\\d+")) {
                return "get_product";
            } else if (method.equals("GET") && uri.equals("/products")) {
                return "list_products";
            } else if (method.equals("POST")) {
                return "create_product";
            } else if (method.equals("PUT")) {
                return "update_product";
            } else if (method.equals("DELETE")) {
                return "delete_product";
            }
            return "unknown";
        }
    }
}
