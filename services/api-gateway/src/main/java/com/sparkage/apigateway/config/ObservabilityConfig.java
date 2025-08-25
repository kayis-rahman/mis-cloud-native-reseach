package com.sparkage.apigateway.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.core.Ordered;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

@Configuration
public class ObservabilityConfig {

    @Bean
    @ConditionalOnMissingBean
    public MeterRegistry meterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    public GlobalFilter customMetricsFilter(MeterRegistry meterRegistry) {
        return new CustomMetricsFilter(meterRegistry);
    }

    public static class CustomMetricsFilter implements GlobalFilter, Ordered {

        private final Timer requestTimer;
        private final MeterRegistry meterRegistry;

        public CustomMetricsFilter(MeterRegistry meterRegistry) {
            this.meterRegistry = meterRegistry;
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

                        Counter.builder("gateway_requests_total")
                                .description("Total number of requests through the gateway")
                                .tags("route", route,
                                      "method", method,
                                      "status", String.valueOf(statusCode))
                                .register(meterRegistry)
                                .increment();
                    });
        }

        @Override
        public int getOrder() {
            return Ordered.HIGHEST_PRECEDENCE;
        }
    }
}
