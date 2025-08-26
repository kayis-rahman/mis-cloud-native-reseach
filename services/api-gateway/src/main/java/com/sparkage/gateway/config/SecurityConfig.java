package com.sparkage.gateway.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.web.server.SecurityWebFilterChain;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebFilter;
import org.springframework.web.server.WebFilterChain;
import reactor.core.publisher.Mono;

import java.util.Arrays;
import java.util.List;

@Configuration
@EnableWebFluxSecurity
public class SecurityConfig {

    @Value("${security.api-keys}")
    private String apiKeys;

    @Value("${security.header-name:X-API-Key}")
    private String headerName;

    @Bean
    public SecurityWebFilterChain securityWebFilterChain(ServerHttpSecurity http) {
        return http
                .csrf(csrf -> csrf.disable())
                .authorizeExchange(exchanges -> exchanges
                        .pathMatchers("/actuator/health", "/actuator/info").permitAll()
                        .pathMatchers("/actuator/**").authenticated()
                        .pathMatchers("/api/**").authenticated()
                        .anyExchange().permitAll()
                )
                .httpBasic(httpBasic -> httpBasic.disable())
                .formLogin(formLogin -> formLogin.disable())
                .build();
    }

    @Bean
    public WebFilter apiKeyAuthenticationFilter() {
        return new ApiKeyAuthenticationFilter(getValidApiKeys(), headerName);
    }

    private List<String> getValidApiKeys() {
        return Arrays.asList(apiKeys.split(","));
    }

    private static class ApiKeyAuthenticationFilter implements WebFilter {
        private final List<String> validApiKeys;
        private final String headerName;

        public ApiKeyAuthenticationFilter(List<String> validApiKeys, String headerName) {
            this.validApiKeys = validApiKeys;
            this.headerName = headerName;
        }

        @Override
        public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
            String path = exchange.getRequest().getPath().value();

            // Skip authentication for health endpoints
            if (path.startsWith("/actuator/health") || path.startsWith("/actuator/info")) {
                return chain.filter(exchange);
            }

            // Skip authentication for non-API paths
            if (!path.startsWith("/api/")) {
                return chain.filter(exchange);
            }

            String apiKey = exchange.getRequest().getHeaders().getFirst(headerName);

            if (apiKey == null || !validApiKeys.contains(apiKey)) {
                // Align with Global ApiKeyFilter behavior and tests: use 403 for missing/invalid API key
                exchange.getResponse().setStatusCode(HttpStatus.FORBIDDEN);
                return exchange.getResponse().setComplete();
            }

            return chain.filter(exchange);
        }
    }
}
