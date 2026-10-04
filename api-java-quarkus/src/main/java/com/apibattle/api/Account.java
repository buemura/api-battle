package com.apibattle.api;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.LockModeType;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.hibernate.annotations.Immutable;

// Accounts are provisioned in the database; the API only reads them.
@Entity
@Immutable
@Table(name = "accounts")
public class Account extends PanacheEntityBase {

    // Balance is always derived from the ledger: credits minus debits.
    private static final String WITH_BALANCE = """
        select new com.apibattle.api.AccountResponse(a.id, a.name,
            coalesce((select sum(case when t.type = 'credit' then t.amount else -t.amount end)
                      from Transaction t where t.accountId = a.id), 0L),
            a.createdAt)
        from Account a""";

    @Id
    public Long id;

    public String name;

    public Instant createdAt;

    public static List<AccountResponse> listWithBalance(Pagination p) {
        return getEntityManager()
                .createQuery(WITH_BALANCE + " order by a.id", AccountResponse.class)
                .setFirstResult(p.offset())
                .setMaxResults(p.pageSize())
                .getResultList();
    }

    public static Optional<AccountResponse> findWithBalance(long id) {
        return getEntityManager()
                .createQuery(WITH_BALANCE + " where a.id = :id", AccountResponse.class)
                .setParameter("id", id)
                .getResultStream()
                .findFirst();
    }

    // SELECT ... FOR UPDATE: serializes concurrent writes to the same account.
    public static Optional<Account> findForUpdate(long id) {
        return findByIdOptional(id, LockModeType.PESSIMISTIC_WRITE);
    }
}
