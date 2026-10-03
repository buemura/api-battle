package com.apibattle.api;

import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LedgerService {

    private final AccountRepository accounts;
    private final TransactionRepository transactions;

    public LedgerService(AccountRepository accounts, TransactionRepository transactions) {
        this.accounts = accounts;
        this.transactions = transactions;
    }

    @Transactional(readOnly = true)
    public PageResponse<AccountResponse> listAccounts(Pagination p) {
        if (p.beyondRange()) {
            return new PageResponse<>(List.of(), p.page(), p.pageSize(), accounts.count());
        }
        Page<AccountResponse> page = accounts.findAllWithBalance(p.pageable());
        return new PageResponse<>(page.getContent(), p.page(), p.pageSize(), page.getTotalElements());
    }

    @Transactional(readOnly = true)
    public AccountResponse getAccount(long id) {
        return accounts.findWithBalance(id).orElseThrow(() -> ApiException.notFound("account not found"));
    }

    @Transactional(readOnly = true)
    public PageResponse<TransactionResponse> listTransactions(long accountId, Pagination p) {
        if (!accounts.existsById(accountId)) {
            throw ApiException.notFound("account not found");
        }
        if (p.beyondRange()) {
            return new PageResponse<>(List.of(), p.page(), p.pageSize(), transactions.countByAccountId(accountId));
        }
        Page<Transaction> page = transactions.findByAccountIdOrderByIdDesc(accountId, p.pageable());
        return new PageResponse<>(
                page.map(TransactionResponse::from).getContent(), p.page(), p.pageSize(), page.getTotalElements());
    }

    @Transactional
    public TransactionResponse addTransaction(long accountId, NewTransaction in) {
        // Lock the account row so concurrent debits can't overdraw it.
        accounts.findForUpdateById(accountId).orElseThrow(() -> ApiException.notFound("account not found"));

        if (in.type().equals("debit") && transactions.balanceOf(accountId) < in.amount()) {
            throw ApiException.unprocessable("insufficient funds");
        }
        Transaction saved = transactions.saveAndFlush(
                new Transaction(accountId, in.type(), in.amount(), in.description()));
        return TransactionResponse.from(saved);
    }

    @Transactional(readOnly = true)
    public TransactionResponse getTransaction(long id) {
        return transactions.findById(id)
                .map(TransactionResponse::from)
                .orElseThrow(() -> ApiException.notFound("transaction not found"));
    }
}
