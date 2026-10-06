package com.pgplatform.auth;

import com.pgplatform.document.DocumentStorageGateway;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class AccountDeletionStorageCleanupService {
    private static final Logger log = LoggerFactory.getLogger(AccountDeletionStorageCleanupService.class);

    private final JdbcTemplate jdbcTemplate;
    private final DocumentStorageGateway storageGateway;

    public AccountDeletionStorageCleanupService(JdbcTemplate jdbcTemplate,
                                                DocumentStorageGateway storageGateway) {
        this.jdbcTemplate = jdbcTemplate;
        this.storageGateway = storageGateway;
    }

    @Transactional
    public void cleanupAudit(UUID auditId) {
        cleanup("and audit_id = ?", auditId);
    }

    @Scheduled(fixedDelayString = "${app.account-deletion.cleanup-interval-ms:300000}")
    @Transactional
    public void retryPending() {
        cleanup("", null);
    }

    private void cleanup(String extraWhere, UUID auditId) {
        String sql = """
                select id, storage_key
                from account_deletion_storage_cleanup
                where status = 'PENDING' and next_attempt_at <= now()
                """ + extraWhere + " order by created_at limit 50 for update skip locked";
        List<CleanupItem> items = auditId == null
                ? jdbcTemplate.query(sql, (rs, row) -> new CleanupItem(
                        rs.getObject("id", UUID.class), rs.getString("storage_key")))
                : jdbcTemplate.query(sql, (rs, row) -> new CleanupItem(
                        rs.getObject("id", UUID.class), rs.getString("storage_key")), auditId);

        for (CleanupItem item : items) {
            try {
                if (item.storageKey() != null) storageGateway.delete(item.storageKey());
                jdbcTemplate.update("""
                        update account_deletion_storage_cleanup
                        set status = 'COMPLETED', storage_key = null, completed_at = now(),
                            updated_at = now(), last_error = null
                        where id = ?
                        """, item.id());
            } catch (RuntimeException exception) {
                String message = exception.getClass().getSimpleName();
                jdbcTemplate.update("""
                        update account_deletion_storage_cleanup
                        set attempt_count = attempt_count + 1, last_error = ?,
                            next_attempt_at = now() + interval '15 minutes', updated_at = now()
                        where id = ?
                        """, message, item.id());
                log.warn("Private-object cleanup remains pending for deletion item {}", item.id());
            }
        }
    }

    private record CleanupItem(UUID id, String storageKey) {
    }
}
