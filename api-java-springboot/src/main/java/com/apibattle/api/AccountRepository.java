package com.apibattle.api;

import jakarta.persistence.LockModeType;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface AccountRepository extends JpaRepository<Account, Long> {

    // Balance is always derived from the ledger: credits minus debits.
    String BALANCE = """
        coalesce((select sum(case when t.type = 'credit' then t.amount else -t.amount end)
                  from Transaction t where t.accountId = a.id), 0L)""";

    @Query(value = "select new com.apibattle.api.AccountResponse(a.id, a.name, " + BALANCE + ", a.createdAt)"
            + " from Account a order by a.id",
            countQuery = "select count(a) from Account a")
    Page<AccountResponse> findAllWithBalance(Pageable pageable);

    @Query("select new com.apibattle.api.AccountResponse(a.id, a.name, " + BALANCE + ", a.createdAt)"
            + " from Account a where a.id = :id")
    Optional<AccountResponse> findWithBalance(long id);

    // SELECT ... FOR UPDATE: serializes concurrent writes to the same account.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<Account> findForUpdateById(long id);
}
