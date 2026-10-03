package com.apibattle.api;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.Immutable;
import org.hibernate.generator.EventType;

// Ledger entries are append-only: Hibernate never issues UPDATEs for them.
@Entity
@Immutable
@Table(name = "transactions")
public class Transaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long accountId;

    private String type;

    private long amount;

    private String description;

    // Set by the database default and read back after insert.
    @Generated(event = EventType.INSERT)
    @Column(insertable = false, updatable = false)
    private Instant createdAt;

    protected Transaction() {}

    public Transaction(Long accountId, String type, long amount, String description) {
        this.accountId = accountId;
        this.type = type;
        this.amount = amount;
        this.description = description;
    }

    public Long getId() { return id; }

    public Long getAccountId() { return accountId; }

    public String getType() { return type; }

    public long getAmount() { return amount; }

    public String getDescription() { return description; }

    public Instant getCreatedAt() { return createdAt; }
}
