package com.sparkage.product.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.Gauge;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.context.annotation.Bean;

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
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

        private final Counter requestCounter;
        private final Timer requestTimer;
        private final Counter productOperationCounter;

        public ProductMetricsFilter() {
            this.requestCounter = Counter.builder("product_service_requests_total")
                    .description("Total requests to product service")
                    .register(meterRegistry);

            this.requestTimer = Timer.builder("product_service_request_duration_seconds")
                    .description("Product service request duration")
                    .register(meterRegistry);

            this.productOperationCounter = Counter.builder("product_operations_total")
                    .description("Total product operations")
                    .register(meterRegistry);

            // Register gauge for active requests
            Gauge.builder("product_service_active_requests")
                    .description("Active requests to product service")
                    .register(meterRegistry, activeRequests, AtomicInteger::get);
        }

        @Override
        protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                      FilterChain filterChain) throws ServletException, IOException {

            Timer.Sample sample = Timer.start(meterRegistry);
            activeRequests.incrementAndGet();

            try {
                filterChain.doFilter(request, response);
            } finally {
                sample.stop(requestTimer);
                activeRequests.decrementAndGet();

                String method = request.getMethod();
                String uri = request.getRequestURI();
                String status = String.valueOf(response.getStatus());

                requestCounter.increment(
                    "method", method,
                    "uri", uri,
                    "status", status
                );

                // Track specific product operations
                if (uri.contains("/products")) {
                    String operation = getOperationType(method, uri);
                    productOperationCounter.increment("operation", operation);
                }
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
