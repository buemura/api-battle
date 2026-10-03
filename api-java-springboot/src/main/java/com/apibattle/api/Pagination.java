package com.apibattle.api;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

record Pagination(int page, int pageSize) {

    private static final int DEFAULT_PAGE_SIZE = 20;
    private static final int MAX_PAGE_SIZE = 100;

    static Pagination parse(String page, String pageSize) {
        int p = parsePositive(page, 1);
        int size = parsePositive(pageSize, DEFAULT_PAGE_SIZE);
        if (p < 1 || size < 1 || size > MAX_PAGE_SIZE) {
            throw ApiException.badRequest("'page' must be >= 1 and 'page_size' must be between 1 and 100");
        }
        return new Pagination(p, size);
    }

    Pageable pageable() {
        return PageRequest.of(page - 1, pageSize);
    }

    // JPA offsets are ints; pages beyond that range are necessarily empty.
    boolean beyondRange() {
        return (long) (page - 1) * pageSize > Integer.MAX_VALUE;
    }

    private static int parsePositive(String raw, int fallback) {
        if (raw == null || raw.isEmpty()) {
            return fallback;
        }
        try {
            return Integer.parseInt(raw);
        } catch (NumberFormatException e) {
            return -1;
        }
    }
}
