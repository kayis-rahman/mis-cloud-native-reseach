package com.sparkage.gateway.filter;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
// Using a simple in-memory fixed-window limiter; no external bucket library
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

@Component
public class RateLimitFilter implements GlobalFilter, Ordered {

    private final int replenishRate;
    private final int burstCapacity;
    private final Cache<String, WindowCounter> cache;
    private final ConcurrentMap<String, WindowCounter> localBuckets = new ConcurrentHashMap<>();

    public RateLimitFilter(
            @Value("${ratelimit.replenish-rate:10}") int replenishRate,
            @Value("${ratelimit.burst-capacity:20}") int burstCapacity,
            @Value("${ratelimit.cache-expire-minutes:10}") int expireMinutes
    ) {
        this.replenishRate = replenishRate;
        this.burstCapacity = burstCapacity;
        this.cache = Caffeine.newBuilder()
                .expireAfterAccess(Duration.ofMinutes(expireMinutes))
                .maximumSize(100_000)
                .build();
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String key = resolveKey(exchange);
        WindowCounter counter = getCounter(key);
        if (counter.allow(burstCapacity, replenishRate)) {
            return chain.filter(exchange);
        }
        exchange.getResponse().setStatusCode(HttpStatus.TOO_MANY_REQUESTS);
        return exchange.getResponse().setComplete();
    }

    private String resolveKey(ServerWebExchange exchange) {
        // Prefer API key header if present, fallback to remote address
        String apiKey = exchange.getRequest().getHeaders().getFirst("X-API-Key");
        if (apiKey != null && !apiKey.isBlank()) return "api:" + apiKey;
        String host = exchange.getRequest().getHeaders().getFirst("X-Forwarded-For");
        if (host != null && !host.isBlank()) return "xff:" + host.split(",")[0].trim();
        return "ip:" + exchange.getRequest().getRemoteAddress();
    }

    private WindowCounter getCounter(String key) {
        WindowCounter existing = cache.getIfPresent(key);
        if (existing != null) return existing;
        return localBuckets.computeIfAbsent(key, k -> {
            WindowCounter counter = new WindowCounter();
            cache.put(k, counter);
            return counter;
        });
    }

    // Simple fixed-window per-second counter
    static class WindowCounter {
        private volatile long windowStartMillis = System.currentTimeMillis();
        private int count = 0;
        synchronized boolean allow(int burst, int perSec) {
            long now = System.currentTimeMillis();
            if (now - windowStartMillis >= 1000) {
                windowStartMillis = now;
                count = 0;
            }
            if (count < burst) {
                count++;
                return true;
            }
            return false;
        }
    }

    @Override
    public int getOrder() {
        return -100; // After ApiKeyFilter
    }
}
