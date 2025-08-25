package com.sparkage.gateway.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.web.server.SecurityWebFilterChain;
import org.springframework.security.web.server.authentication.ServerAuthenticationConverter;
import org.springframework.security.web.server.authentication.ServerAuthenticationFailureHandler;
import org.springframework.security.web.server.authentication.ServerAuthenticationSuccessHandler;
import org.springframework.web.server.ServerWebExchange;
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
                .addFilterBefore(new ApiKeyAuthenticationFilter(getValidApiKeys(), headerName),
                                org.springframework.security.web.server.authentication.AuthenticationWebFilter.class)
                .build();
    }

    private List<String> getValidApiKeys() {
        return Arrays.asList(apiKeys.split(","));
    }

    private static class ApiKeyAuthenticationFilter implements org.springframework.web.server.WebFilter {
        private final List<String> validApiKeys;
        private final String headerName;

        public ApiKeyAuthenticationFilter(List<String> validApiKeys, String headerName) {
            this.validApiKeys = validApiKeys;
            this.headerName = headerName;
        }

        @Override
        public Mono<Void> filter(ServerWebExchange exchange, org.springframework.web.server.WebFilterChain chain) {
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
                exchange.getResponse().setStatusCode(org.springframework.http.HttpStatus.UNAUTHORIZED);
                return exchange.getResponse().setComplete();
            }

            return chain.filter(exchange);
        }
    }
}
