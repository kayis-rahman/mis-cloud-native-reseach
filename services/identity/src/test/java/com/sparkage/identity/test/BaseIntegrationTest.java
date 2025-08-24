package com.sparkage.identity.test;

import org.junit.jupiter.api.TestInstance;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * Base class that starts a reusable PostgreSQL Testcontainers instance and
 * wires Spring datasource properties for integration tests.
 * When the system property "disableTestcontainers" or env var "DISABLE_TESTCONTAINERS"
 * is set to true, fallback to an in-memory H2 database so tests can run inside
 * environments without a Docker daemon (e.g., during docker build).
 */
@SpringBootTest
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
public abstract class BaseIntegrationTest {

    private static final boolean DISABLE_TC = Boolean.parseBoolean(System.getProperty("disableTestcontainers", System.getenv().getOrDefault("DISABLE_TESTCONTAINERS", "false")));

    // Singleton static container; used only when DISABLE_TC is false
    private static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("postgres:16-alpine").asCompatibleSubstituteFor("postgres")
    )
            .withDatabaseName("identitydb")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void registerDataSourceProps(DynamicPropertyRegistry registry) {
        if (DISABLE_TC) {
            // H2 in-memory fallback with PostgreSQL compatibility mode
            registry.add("spring.datasource.url", () -> "jdbc:h2:mem:identitydb;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH");
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
            // Keep Hibernate behavior similar to prod for integration tests
            registry.add("spring.jpa.hibernate.ddl-auto", () -> "update");
            registry.add("spring.jpa.database-platform", () -> "org.hibernate.dialect.PostgreSQLDialect");
        }
    }
}
