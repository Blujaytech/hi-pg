package com.pgplatform.expense;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ExpenseRepository extends JpaRepository<Expense, UUID> {
    Optional<Expense> findByIdAndDeletedAtIsNull(UUID id);
    List<Expense> findAllByPgIdAndDeletedAtIsNullOrderByExpenseDateDesc(UUID pgId);

    @Query("select coalesce(sum(e.amount), 0) from Expense e " +
           "where e.pg.owner.id = :ownerId and e.deletedAt is null " +
           "and e.expenseDate >= :from and e.expenseDate <= :to")
    BigDecimal sumByOwnerIdBetween(@Param("ownerId") UUID ownerId, @Param("from") LocalDate from, @Param("to") LocalDate to);
    @Query("select coalesce(sum(e.amount), 0) from Expense e " +
           "where e.pg.id = :pgId and e.deletedAt is null " +
           "and e.expenseDate >= :from and e.expenseDate <= :to")
    BigDecimal sumByPgIdBetween(@Param("pgId") UUID pgId, @Param("from") LocalDate from, @Param("to") LocalDate to);
}
