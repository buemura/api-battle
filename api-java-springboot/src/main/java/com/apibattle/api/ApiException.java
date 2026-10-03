package com.apibattle.api;

import org.springframework.http.HttpStatus;

// Rendered as {"error": "<message>"} with the given status.
public class ApiException extends RuntimeException {

    private final HttpStatus status;

    public ApiException(HttpStatus status, String message) {
        super(message, null, false, false);
        this.status = status;
    }

    public HttpStatus status() { return status; }

    static ApiException badRequest(String message) { return new ApiException(HttpStatus.BAD_REQUEST, message); }

    static ApiException notFound(String message) { return new ApiException(HttpStatus.NOT_FOUND, message); }

    static ApiException unprocessable(String message) {
        return new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, message);
    }
}
