package api

import (
	"encoding/json"
	"time"
)

// Timestamp renders as ISO-8601 UTC with millisecond precision,
// e.g. "2026-10-03T02:44:35.274Z".
type Timestamp time.Time

func (t Timestamp) MarshalJSON() ([]byte, error) {
	return json.Marshal(time.Time(t).UTC().Format("2006-01-02T15:04:05.000Z"))
}

type Account struct {
	ID        int64     `json:"id"`
	Name      string    `json:"name"`
	Balance   int64     `json:"balance"`
	CreatedAt Timestamp `json:"created_at"`
}

type Transaction struct {
	ID          int64     `json:"id"`
	AccountID   int64     `json:"account_id"`
	Type        string    `json:"type"`
	Amount      int64     `json:"amount"`
	Description *string   `json:"description"`
	CreatedAt   Timestamp `json:"created_at"`
}

type Page[T any] struct {
	Data     []T   `json:"data"`
	Page     int   `json:"page"`
	PageSize int   `json:"page_size"`
	Total    int64 `json:"total"`
}
