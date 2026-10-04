package com.apibattle.api;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import java.util.List;

@ApplicationScoped
public class LedgerService {

    public PageResponse<AccountResponse> listAccounts(Pagination p) {
        List<AccountResponse> data = p.beyondRange() ? List.of() : Account.listWithBalance(p);
        return new PageResponse<>(data, p.page(), p.pageSize(), Account.count());
    }

    public AccountResponse getAccount(long id) {
        return Account.findWithBalance(id).orElseThrow(() -> ApiException.notFound("account not found"));
    }

    public PageResponse<TransactionResponse> listTransactions(long accountId, Pagination p) {
        if (Account.findByIdOptional(accountId).isEmpty()) {
            throw ApiException.notFound("account not found");
        }
        List<TransactionResponse> data = p.beyondRange()
                ? List.of()
                : Transaction.listLatest(accountId, p).stream().map(TransactionResponse::from).toList();
        return new PageResponse<>(data, p.page(), p.pageSize(), Transaction.countByAccount(accountId));
    }

    @Transactional
    public TransactionResponse addTransaction(long accountId, NewTransaction in) {
        // Lock the account row so concurrent debits can't overdraw it.
        Account.findForUpdate(accountId).orElseThrow(() -> ApiException.notFound("account not found"));

        if (in.type().equals("debit") && Transaction.balanceOf(accountId) < in.amount()) {
            throw ApiException.unprocessable("insufficient funds");
        }
        Transaction tx = new Transaction(accountId, in.type(), in.amount(), in.description());
        tx.persistAndFlush();
        return TransactionResponse.from(tx);
    }

    public TransactionResponse getTransaction(long id) {
        return Transaction.<Transaction>findByIdOptional(id)
                .map(TransactionResponse::from)
                .orElseThrow(() -> ApiException.notFound("transaction not found"));
    }
}
