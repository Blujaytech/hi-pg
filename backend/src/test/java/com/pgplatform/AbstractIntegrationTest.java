package com.pgplatform;

import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.PostgreSQLContainer;

/** Base for backend integration tests: a real Postgres via Testcontainers, not H2/mocks (see CLAUDE.md). */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
public abstract class AbstractIntegrationTest {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /**
     * One database for the complete Maven test JVM. A JUnit {@code @Container}
     * declared on this inherited base class is started/stopped once per test
     * subclass, while Spring caches and reuses the first application context.
     * That leaves later classes pointing at a stopped container port. Starting
     * this singleton once keeps the cached datasource valid for the full suite;
     * Testcontainers/Ryuk still removes it when the JVM exits.
     */
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("pgplatform_test")
            .withUsername("test")
            .withPassword("test");

    static {
        postgres.start();
    }

    @DynamicPropertySource
    static void registerProps(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    /** Every integration test starts from the migrated schema with no domain rows. */
    @BeforeEach
    void cleanDatabase() {
        String tables = jdbcTemplate.queryForObject("""
                select string_agg(format('%I.%I', schemaname, tablename), ', ')
                from pg_tables
                where schemaname = 'public'
                  and tablename <> 'flyway_schema_history'
                """, String.class);
        if (tables != null && !tables.isBlank()) {
            jdbcTemplate.execute("truncate table " + tables + " restart identity cascade");
        }
    }
}
