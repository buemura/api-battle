package com.apibattle.api;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import io.quarkus.panache.common.Sort;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.List;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.Immutable;
import org.hibernate.generator.EventType;

// Ledger entries are append-only: Hibernate never issues UPDATEs for them.
@Entity
@Immutable
@Table(name = "transactions")
public class Transaction extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    public Long accountId;

    public String type;

    public long amount;

    public String description;

    // Set by the database default and read back after insert.
    @Generated(event = EventType.INSERT)
    @Column(insertable = false, updatable = false)
    public Instant createdAt;

    protected Transaction() {}

    public Transaction(long accountId, String type, long amount, String description) {
        this.accountId = accountId;
        this.type = type;
        this.amount = amount;
        this.description = description;
    }

    public static List<Transaction> listLatest(long accountId, Pagination p) {
        return find("accountId", Sort.descending("id"), accountId)
                .range(p.offset(), p.offset() + p.pageSize() - 1)
                .list();
    }

    public static long countByAccount(long accountId) {
        return count("accountId", accountId);
    }

    public static long balanceOf(long accountId) {
        return getEntityManager()
                .createQuery("""
                    select coalesce(sum(case when t.type = 'credit' then t.amount else -t.amount end), 0L)
                    from Transaction t where t.accountId = :accountId""", Long.class)
                .setParameter("accountId", accountId)
                .getSingleResult();
    }
}
