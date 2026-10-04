package com.apibattle.api;

import jakarta.ws.rs.core.Response.Status;

// Rendered as {"error": "<message>"} with the given status.
public class ApiException extends RuntimeException {

    private final int status;

    public ApiException(int status, String message) {
        super(message, null, false, false);
        this.status = status;
    }

    public int status() { return status; }

    static ApiException badRequest(String message) { return new ApiException(Status.BAD_REQUEST.getStatusCode(), message); }

    static ApiException notFound(String message) { return new ApiException(Status.NOT_FOUND.getStatusCode(), message); }

    static ApiException unprocessable(String message) { return new ApiException(422, message); }
}
