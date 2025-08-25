package com.sparkage.apigateway.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

@Configuration
public class ObservabilityConfig {

    @Autowired
    private MeterRegistry meterRegistry;

    @Bean
    public GlobalFilter customMetricsFilter() {
        return new CustomMetricsFilter(meterRegistry);
    }

    public static class CustomMetricsFilter implements GlobalFilter, Ordered {

        private final Counter requestCounter;
        private final Timer requestTimer;
        private final MeterRegistry meterRegistry;

        public CustomMetricsFilter(MeterRegistry meterRegistry) {
            this.meterRegistry = meterRegistry;
            this.requestCounter = Counter.builder("gateway_requests_total")
                    .description("Total number of requests through the gateway")
                    .register(meterRegistry);
            this.requestTimer = Timer.builder("gateway_request_duration")
                    .description("Gateway request duration")
                    .register(meterRegistry);
        }

        @Override
        public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
            Timer.Sample sample = Timer.start(meterRegistry);

            return chain.filter(exchange)
                    .doFinally(signalType -> {
                        sample.stop(requestTimer);

                        String route = exchange.getRequest().getPath().value();
                        String method = exchange.getRequest().getMethod().name();
                        int statusCode = exchange.getResponse().getStatusCode() != null ?
                            exchange.getResponse().getStatusCode().value() : 0;

                        requestCounter.increment(
                            "route", route,
                            "method", method,
                            "status", String.valueOf(statusCode)
                        );
                    });
        }

        @Override
        public int getOrder() {
            return Ordered.HIGHEST_PRECEDENCE;
        }
    }
}
