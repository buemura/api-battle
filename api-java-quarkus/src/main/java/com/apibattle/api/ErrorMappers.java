package com.apibattle.api;

import jakarta.ws.rs.NotAllowedException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.jboss.logging.Logger;
import org.jboss.resteasy.reactive.server.ServerExceptionMapper;

public class ErrorMappers {

    private static final Logger log = Logger.getLogger(ErrorMappers.class);

    @ServerExceptionMapper
    Response api(ApiException e) {
        return error(e.status(), e.getMessage());
    }

    @ServerExceptionMapper
    Response noRoute(NotFoundException e) {
        return error(404, "not found");
    }

    @ServerExceptionMapper
    Response noMethod(NotAllowedException e) {
        return error(405, "method not allowed");
    }

    // Anything unexpected is logged and hidden behind a generic 500.
    @ServerExceptionMapper
    Response unexpected(Exception e) {
        log.error("request failed", e);
        return error(500, "internal server error");
    }

    private static Response error(int status, String message) {
        return Response.status(status).type(MediaType.APPLICATION_JSON_TYPE).entity(new ErrorResponse(message)).build();
    }
}
