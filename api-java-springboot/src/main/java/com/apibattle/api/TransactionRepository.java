package com.apibattle.api;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    Page<Transaction> findByAccountIdOrderByIdDesc(long accountId, Pageable pageable);

    long countByAccountId(long accountId);

    @Query("""
        select coalesce(sum(case when t.type = 'credit' then t.amount else -t.amount end), 0L)
        from Transaction t where t.accountId = :accountId""")
    long balanceOf(long accountId);
}
