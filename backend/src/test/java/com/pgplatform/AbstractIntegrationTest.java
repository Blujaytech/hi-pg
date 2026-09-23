package com.pgplatform;

import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.PostgreSQLContainer;

import java.util.UUID;

/** Base for backend integration tests: a real Postgres via Testcontainers, not H2/mocks (see CLAUDE.md). */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
public abstract class AbstractIntegrationTest {

    @Autowired
    protected JdbcTemplate jdbcTemplate;

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

    /**
     * Existing booking tests predate the customer-profile gate. Give their test
     * users a complete monthly profile without coupling every booking fixture to
     * CustomerProfileService's controller-shaped request objects.
     */
    protected void completeMonthlyCustomerProfile(UUID userId) {
        String fullName = jdbcTemplate.queryForObject(
                "select full_name from users where id = ?", String.class, userId);
        jdbcTemplate.update("""
                insert into customer_profiles
                    (id, user_id, full_name, occupation, permanent_address,
                     identity_type, identity_last_four, created_at, updated_at)
                values (?, ?, ?, 'Student', '1 Test Address', 'VOTER_ID', 'A1B2', now(), now())
                """, UUID.randomUUID(), userId, fullName);
        insertLegalAcceptance(userId, "TERMS");
        insertLegalAcceptance(userId, "PRIVACY");
    }

    private void insertLegalAcceptance(UUID userId, String documentType) {
        jdbcTemplate.update("""
                insert into legal_acceptances
                    (id, user_id, document_type, document_version, accepted_at, created_at, updated_at)
                values (?, ?, ?, '2026-09-22', now(), now(), now())
                """, UUID.randomUUID(), userId, documentType);
    }
}
