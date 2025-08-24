package com.sparkage.payment.test;

import org.junit.jupiter.api.TestInstance;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * Base class that starts a reusable PostgreSQL Testcontainers instance and
 * wires Spring datasource properties for integration tests for the payment service.
 * Falls back to H2 when disableTestcontainers=true or DISABLE_TESTCONTAINERS=true.
 */
@SpringBootTest
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
public abstract class BaseIntegrationTest {

    private static final boolean DISABLE_TC = Boolean.parseBoolean(System.getProperty("disableTestcontainers", System.getenv().getOrDefault("DISABLE_TESTCONTAINERS", "false")));

    private static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("postgres:16-alpine").asCompatibleSubstituteFor("postgres")
    )
            .withDatabaseName("paymentdb")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void registerDataSourceProps(DynamicPropertyRegistry registry) {
        if (DISABLE_TC) {
            registry.add("spring.datasource.url", () -> "jdbc:h2:mem:paymentdb;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH");
            registry.add("spring.datasource.username", () -> "sa");
            registry.add("spring.datasource.password", () -> "");
            registry.add("spring.datasource.driver-class-name", () -> "org.h2.Driver");
            registry.add("spring.jpa.hibernate.ddl-auto", () -> "update");
            registry.add("spring.jpa.database-platform", () -> "org.hibernate.dialect.H2Dialect");
        } else {
            if (!POSTGRES.isRunning()) {
                POSTGRES.start();
            }
            registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
            registry.add("spring.datasource.username", POSTGRES::getUsername);
            registry.add("spring.datasource.password", POSTGRES::getPassword);
            registry.add("spring.datasource.driver-class-name", () -> "org.postgresql.Driver");
            registry.add("spring.jpa.hibernate.ddl-auto", () -> "update");
            registry.add("spring.jpa.database-platform", () -> "org.hibernate.dialect.PostgreSQLDialect");
        }
    }
}
