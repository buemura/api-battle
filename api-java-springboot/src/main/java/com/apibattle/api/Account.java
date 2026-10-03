package com.apibattle.api;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import org.hibernate.annotations.Immutable;

// Accounts are provisioned in the database; the API only reads them.
@Entity
@Immutable
@Table(name = "accounts")
public class Account {

    @Id
    private Long id;

    private String name;

    private Instant createdAt;

    protected Account() {}

    public Long getId() { return id; }

    public String getName() { return name; }

    public Instant getCreatedAt() { return createdAt; }
}
