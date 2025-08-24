package com.sparkage.gateway;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.web.reactive.server.WebTestClient;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = {
        "security.api-keys=itest",
        "security.header-name=X-API-Key",
        "ratelimit.replenish-rate=100",
        "ratelimit.burst-capacity=100"
    })
class ApiGatewayIntegrationTest {

    @LocalServerPort
    int port;

    @Autowired
    private WebTestClient webTestClient;

    @Test
    void actuatorHealthAccessibleWithoutApiKey() {
        webTestClient.get()
                .uri("/actuator/health")
                .exchange()
                .expectStatus().isOk();
    }

    @Test
    void unknownPathRequiresApiKey() {
        // Without key -> 403 from ApiKeyFilter
        webTestClient.get()
                .uri("/api/cart/test")
                .exchange()
                .expectStatus().isForbidden();

        // With valid key -> should pass filters; no route exists so typically 404
        webTestClient.get()
                .uri("/unknown-path")
                .header("X-API-Key", "itest")
                .exchange()
                .expectStatus().value(status -> {
                    // Accept any non-auth errors (i.e., not 401/403), commonly 404
                    if (status == 401 || status == 403) {
                        throw new AssertionError("Expected to bypass ApiKeyFilter with valid key, but got status=" + status);
                    }
                });
    }
}
