package api

import (
	"bytes"
	"encoding/json"
	"strconv"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
)

const (
	defaultPageSize      = 20
	maxPageSize          = 100
	maxDescriptionLength = 255
)

type pagination struct {
	page, pageSize int
}

func (p pagination) limit() int  { return p.pageSize }
func (p pagination) offset() int { return (p.page - 1) * p.pageSize }

func parsePagination(c *gin.Context) (pagination, error) {
	invalid := badRequest("'page' must be >= 1 and 'page_size' must be between 1 and 100")

	page, ok := parsePositive(c.Query("page"), 1)
	if !ok {
		return pagination{}, invalid
	}
	pageSize, ok := parsePositive(c.Query("page_size"), defaultPageSize)
	if !ok || pageSize > maxPageSize {
		return pagination{}, invalid
	}
	return pagination{page: page, pageSize: pageSize}, nil
}

func parsePositive(raw string, fallback int) (int, bool) {
	if raw == "" {
		return fallback, true
	}
	v, err := strconv.ParseInt(raw, 10, 32)
	if err != nil || v < 1 {
		return 0, false
	}
	return int(v), true
}

// parseID reads the numeric :id path param. Non-numeric ids can never match a
// resource, so they are reported as 404.
func parseID(c *gin.Context) (int64, error) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		return 0, notFound("not found")
	}
	return id, nil
}

type newTransaction struct {
	Type        string
	Amount      int64
	Description *string
}

// parseNewTransaction validates field by field so each problem gets a
// specific message.
func parseNewTransaction(c *gin.Context) (newTransaction, error) {
	var body map[string]json.RawMessage
	raw, err := c.GetRawData()
	if err == nil {
		err = json.Unmarshal(raw, &body)
	}
	if err != nil || body == nil {
		return newTransaction{}, badRequest("request body must be JSON")
	}

	var tx newTransaction
	if json.Unmarshal(body["type"], &tx.Type) != nil || (tx.Type != "credit" && tx.Type != "debit") {
		return newTransaction{}, badRequest("'type' must be either 'credit' or 'debit'")
	}

	// Decode via json.Number so floats like 10.5 are rejected rather than truncated.
	var amount any
	dec := json.NewDecoder(bytes.NewReader(body["amount"]))
	dec.UseNumber()
	var num json.Number
	var isNum bool
	if dec.Decode(&amount) == nil {
		num, isNum = amount.(json.Number)
	}
	if !isNum {
		return newTransaction{}, badRequest("'amount' must be a positive integer (minor units, e.g. cents)")
	}
	if tx.Amount, err = num.Int64(); err != nil || tx.Amount <= 0 {
		return newTransaction{}, badRequest("'amount' must be a positive integer (minor units, e.g. cents)")
	}

	if d, ok := body["description"]; ok && string(d) != "null" {
		var s string
		if json.Unmarshal(d, &s) != nil || utf8.RuneCountInString(s) > maxDescriptionLength {
			return newTransaction{}, badRequest("'description' must be a string of at most 255 characters")
		}
		if s != "" {
			tx.Description = &s
		}
	}
	return tx, nil
}
