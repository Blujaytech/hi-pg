package com.pgplatform.expense;

import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.expense.dto.ExpenseCreateRequest;
import com.pgplatform.expense.dto.ExpenseResponse;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class ExpenseService {

    private final ExpenseRepository expenseRepository;
    private final PgService pgService;

    public ExpenseService(ExpenseRepository expenseRepository, PgService pgService) {
        this.expenseRepository = expenseRepository;
        this.pgService = pgService;
    }

    @Transactional
    public ExpenseResponse create(UUID pgId, UUID ownerId, ExpenseCreateRequest request) {
        Pg pg = pgService.requireOwnedPg(pgId, ownerId);

        Expense expense = new Expense();
        expense.setPg(pg);
        expense.setCategory(request.category());
        expense.setDescription(request.description());
        expense.setAmount(request.amount());
        expense.setExpenseDate(request.expenseDate());

        return ExpenseResponse.from(expenseRepository.save(expense));
    }

    @Transactional(readOnly = true)
    public List<ExpenseResponse> listForPg(UUID pgId, UUID ownerId) {
        pgService.requireOwnedPg(pgId, ownerId);
        return expenseRepository.findAllByPgIdAndDeletedAtIsNullOrderByExpenseDateDesc(pgId)
                .stream().map(ExpenseResponse::from).toList();
    }

    @Transactional
    public ExpenseResponse update(UUID expenseId, UUID ownerId, ExpenseCreateRequest request) {
        Expense expense = requireOwnedExpense(expenseId, ownerId);
        expense.setCategory(request.category());
        expense.setDescription(request.description());
        expense.setAmount(request.amount());
        expense.setExpenseDate(request.expenseDate());
        return ExpenseResponse.from(expenseRepository.save(expense));
    }

    @Transactional
    public void delete(UUID expenseId, UUID ownerId) {
        Expense expense = requireOwnedExpense(expenseId, ownerId);
        expense.markDeleted();
        expenseRepository.save(expense);
    }

    private Expense requireOwnedExpense(UUID expenseId, UUID ownerId) {
        Expense expense = expenseRepository.findByIdAndDeletedAtIsNull(expenseId)
                .orElseThrow(() -> new NotFoundException("Expense not found"));
        if (!expense.getPg().getOwner().getId().equals(ownerId)) {
            throw new ForbiddenException("You do not have access to this expense");
        }
        return expense;
    }
}
