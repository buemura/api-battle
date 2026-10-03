package api

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"
)

// APIError is rendered as {"error": "<message>"} with the given status.
type APIError struct {
	Status  int
	Message string
}

func (e *APIError) Error() string { return e.Message }

func badRequest(msg string) *APIError { return &APIError{http.StatusBadRequest, msg} }
func notFound(msg string) *APIError   { return &APIError{http.StatusNotFound, msg} }
func unprocessable(msg string) *APIError {
	return &APIError{http.StatusUnprocessableEntity, msg}
}

// respondError writes an APIError as-is; anything else is logged and hidden
// behind a generic 500.
func respondError(c *gin.Context, err error) {
	var apiErr *APIError
	if errors.As(err, &apiErr) {
		c.AbortWithStatusPureJSON(apiErr.Status, gin.H{"error": apiErr.Message})
		return
	}
	slog.ErrorContext(c.Request.Context(), "request failed", "error", err, "path", c.FullPath())
	c.AbortWithStatusPureJSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
}
