package com.sparkage.gateway.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/fallback")
public class FallbackController {

    @GetMapping("/identity")
    @PostMapping("/identity")
    public Mono<ResponseEntity<Map<String, Object>>> identityFallback() {
        return createFallbackResponse("Identity service is temporarily unavailable");
    }

    @GetMapping("/product")
    @PostMapping("/product")
    public Mono<ResponseEntity<Map<String, Object>>> productFallback() {
        return createFallbackResponse("Product service is temporarily unavailable");
    }

    @GetMapping("/cart")
    @PostMapping("/cart")
    public Mono<ResponseEntity<Map<String, Object>>> cartFallback() {
        return createFallbackResponse("Cart service is temporarily unavailable");
    }

    @GetMapping("/order")
    @PostMapping("/order")
    public Mono<ResponseEntity<Map<String, Object>>> orderFallback() {
        return createFallbackResponse("Order service is temporarily unavailable");
    }

    @GetMapping("/payment")
    @PostMapping("/payment")
    public Mono<ResponseEntity<Map<String, Object>>> paymentFallback() {
        return createFallbackResponse("Payment service is temporarily unavailable");
    }

    private Mono<ResponseEntity<Map<String, Object>>> createFallbackResponse(String message) {
        Map<String, Object> response = Map.of(
            "error", "Service Unavailable",
            "message", message,
            "timestamp", Instant.now().toString(),
            "status", HttpStatus.SERVICE_UNAVAILABLE.value()
        );

        return Mono.just(ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(response));
    }
}
