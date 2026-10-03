using Microsoft.EntityFrameworkCore;

namespace ApiBattleApi.Data;

public enum TransactionType
{
    Credit,
    Debit,
}

public class Account
{
    public long Id { get; set; }
    public string Name { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public List<Transaction> Transactions { get; set; } = [];
}

public class Transaction
{
    public long Id { get; set; }
    public long AccountId { get; set; }
    public TransactionType Type { get; set; }
    public long Amount { get; set; }
    public string? Description { get; set; }
    public DateTime CreatedAt { get; set; }
}

/// Maps the schema created by db/init.sql; it is never migrated from here.
public class ApiBattleDbContext(DbContextOptions<ApiBattleDbContext> options) : DbContext(options)
{
    public DbSet<Account> Accounts => Set<Account>();
    public DbSet<Transaction> Transactions => Set<Transaction>();

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<Account>(e =>
        {
            e.ToTable("accounts");
            e.Property(a => a.Id).HasColumnName("id");
            e.Property(a => a.Name).HasColumnName("name").HasMaxLength(100);
            e.Property(a => a.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("now()");
            e.HasMany(a => a.Transactions).WithOne().HasForeignKey(t => t.AccountId);
        });

        model.Entity<Transaction>(e =>
        {
            e.ToTable("transactions");
            e.Property(t => t.Id).HasColumnName("id");
            e.Property(t => t.AccountId).HasColumnName("account_id");
            e.Property(t => t.Type)
                .HasColumnName("type")
                .HasMaxLength(6)
                .HasConversion(
                    v => v == TransactionType.Credit ? "credit" : "debit",
                    v => v == "credit" ? TransactionType.Credit : TransactionType.Debit);
            e.Property(t => t.Amount).HasColumnName("amount");
            e.Property(t => t.Description).HasColumnName("description").HasMaxLength(255);
            e.Property(t => t.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("now()");
        });
    }
}
