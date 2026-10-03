package api

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// accountSelect returns accounts with their balance derived from the ledger.
// Callers append a WHERE and/or ORDER BY clause.
const accountSelect = `
	SELECT a.id, a.name, COALESCE(b.balance, 0) AS balance, a.created_at
	FROM accounts a LEFT JOIN LATERAL (
		SELECT SUM(CASE WHEN t.type = 'credit' THEN t.amount ELSE -t.amount END)::bigint AS balance
		FROM transactions t WHERE t.account_id = a.id
	) b ON true`

const transactionColumns = "id, account_id, type, amount, description, created_at"

type Handler struct {
	db *pgxpool.Pool
}

func NewRouter(db *pgxpool.Pool) *gin.Engine {
	h := &Handler{db: db}

	r := gin.New()
	r.Use(gin.Recovery(), requestLogger())
	r.HandleMethodNotAllowed = true
	r.NoRoute(func(c *gin.Context) { respondError(c, notFound("not found")) })
	r.NoMethod(func(c *gin.Context) {
		respondError(c, &APIError{http.StatusMethodNotAllowed, "method not allowed"})
	})

	r.GET("/health", h.health)
	r.GET("/accounts", h.listAccounts)
	r.GET("/accounts/:id", h.getAccount)
	r.GET("/accounts/:id/transactions", h.listTransactions)
	r.POST("/accounts/:id/transactions", h.addTransaction)
	r.GET("/transactions/:id", h.getTransaction)
	r.GET("/docs", swaggerUI)
	r.GET("/openapi.yaml", openAPISpec)
	return r
}

func (h *Handler) health(c *gin.Context) {
	c.String(http.StatusOK, "ok")
}

func (h *Handler) listAccounts(c *gin.Context) {
	p, err := parsePagination(c)
	if err != nil {
		respondError(c, err)
		return
	}
	ctx := c.Request.Context()

	var total int64
	if err := h.db.QueryRow(ctx, "SELECT count(*) FROM accounts").Scan(&total); err != nil {
		respondError(c, err)
		return
	}
	rows, _ := h.db.Query(ctx, accountSelect+" ORDER BY a.id LIMIT $1 OFFSET $2", p.limit(), p.offset())
	data, err := pgx.CollectRows(rows, scanAccount)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, Page[Account]{Data: data, Page: p.page, PageSize: p.pageSize, Total: total})
}

func (h *Handler) getAccount(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		respondError(c, err)
		return
	}
	rows, _ := h.db.Query(c.Request.Context(), accountSelect+" WHERE a.id = $1", id)
	account, err := pgx.CollectExactlyOneRow(rows, scanAccount)
	if err != nil {
		respondError(c, notFoundIfNoRows(err, "account not found"))
		return
	}
	c.JSON(http.StatusOK, account)
}

func (h *Handler) listTransactions(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		respondError(c, err)
		return
	}
	p, err := parsePagination(c)
	if err != nil {
		respondError(c, err)
		return
	}
	ctx := c.Request.Context()

	var total int64
	err = h.db.QueryRow(ctx, `
		SELECT (SELECT count(*) FROM transactions WHERE account_id = a.id)
		FROM accounts a WHERE a.id = $1`, id).Scan(&total)
	if err != nil {
		respondError(c, notFoundIfNoRows(err, "account not found"))
		return
	}

	rows, _ := h.db.Query(ctx,
		"SELECT "+transactionColumns+" FROM transactions WHERE account_id = $1 ORDER BY id DESC LIMIT $2 OFFSET $3",
		id, p.limit(), p.offset())
	data, err := pgx.CollectRows(rows, scanTransaction)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, Page[Transaction]{Data: data, Page: p.page, PageSize: p.pageSize, Total: total})
}

func (h *Handler) addTransaction(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		respondError(c, err)
		return
	}
	in, err := parseNewTransaction(c)
	if err != nil {
		respondError(c, err)
		return
	}

	var created Transaction
	err = pgx.BeginFunc(c.Request.Context(), h.db, func(tx pgx.Tx) error {
		created, err = insertTransaction(c.Request.Context(), tx, id, in)
		return err
	})
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, created)
}

func insertTransaction(ctx context.Context, tx pgx.Tx, accountID int64, in newTransaction) (Transaction, error) {
	// Lock the account row so concurrent debits can't overdraw it.
	var locked int64
	err := tx.QueryRow(ctx, "SELECT id FROM accounts WHERE id = $1 FOR UPDATE", accountID).Scan(&locked)
	if err != nil {
		return Transaction{}, notFoundIfNoRows(err, "account not found")
	}

	if in.Type == "debit" {
		var balance int64
		err := tx.QueryRow(ctx, `
			SELECT COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END), 0)::bigint
			FROM transactions WHERE account_id = $1`, accountID).Scan(&balance)
		if err != nil {
			return Transaction{}, err
		}
		if balance < in.Amount {
			return Transaction{}, unprocessable("insufficient funds")
		}
	}

	rows, _ := tx.Query(ctx,
		"INSERT INTO transactions (account_id, type, amount, description) VALUES ($1, $2, $3, $4) RETURNING "+transactionColumns,
		accountID, in.Type, in.Amount, in.Description)
	return pgx.CollectExactlyOneRow(rows, scanTransaction)
}

func (h *Handler) getTransaction(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		respondError(c, err)
		return
	}
	rows, _ := h.db.Query(c.Request.Context(), "SELECT "+transactionColumns+" FROM transactions WHERE id = $1", id)
	t, err := pgx.CollectExactlyOneRow(rows, scanTransaction)
	if err != nil {
		respondError(c, notFoundIfNoRows(err, "transaction not found"))
		return
	}
	c.JSON(http.StatusOK, t)
}

func scanAccount(row pgx.CollectableRow) (Account, error) {
	var a Account
	err := row.Scan(&a.ID, &a.Name, &a.Balance, (*time.Time)(&a.CreatedAt))
	return a, err
}

func scanTransaction(row pgx.CollectableRow) (Transaction, error) {
	var t Transaction
	err := row.Scan(&t.ID, &t.AccountID, &t.Type, &t.Amount, &t.Description, (*time.Time)(&t.CreatedAt))
	return t, err
}

func notFoundIfNoRows(err error, msg string) error {
	if errors.Is(err, pgx.ErrNoRows) {
		return notFound(msg)
	}
	return err
}
