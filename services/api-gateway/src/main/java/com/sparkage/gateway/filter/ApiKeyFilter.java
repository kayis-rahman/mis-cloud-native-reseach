package com.sparkage.gateway.filter;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.HttpStatus;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Component
public class ApiKeyFilter implements GlobalFilter, Ordered {

    private final Set<String> validKeys;
    private final String headerName;
    private final List<String> allowList;

    public ApiKeyFilter(
            @Value("${security.api-keys:}") String keys,
            @Value("${security.header-name:X-API-Key}") String headerName,
            @Value("${security.allowlist-paths:}") List<String> allowList
    ) {
        this.headerName = headerName;
        this.allowList = allowList;
        if (keys == null || keys.isBlank()) {
            this.validKeys = new HashSet<>();
        } else {
            this.validKeys = new HashSet<>(Arrays.asList(keys.split(",")));
        }
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String path = exchange.getRequest().getURI().getPath();
        // Skip security for allowlisted paths
        if (allowList != null && allowList.stream().anyMatch(path::startsWith)) {
            return chain.filter(exchange);
        }

        // If no keys configured, reject by default for security
        if (validKeys.isEmpty()) {
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }

        ServerHttpRequest request = exchange.getRequest();
        List<String> headers = request.getHeaders().get(headerName);
        String provided = headers == null || headers.isEmpty() ? null : headers.get(0);
        if (provided == null || !validKeys.contains(provided)) {
            exchange.getResponse().setStatusCode(HttpStatus.FORBIDDEN);
            return exchange.getResponse().setComplete();
        }
        return chain.filter(exchange);
    }

    @Override
    public int getOrder() {
        // Run before rate limit to avoid counting unauthorized requests
        return -200;
    }
}
