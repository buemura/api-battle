<?php

namespace App\Support;

use App\Exceptions\ApiException;

final class PathId
{
    /**
     * Numeric path id. Ids that can't be a valid BIGINT never match a resource,
     * so they are reported as 404 rather than 400.
     */
    public static function parse(string $raw): int
    {
        $id = filter_var($raw, FILTER_VALIDATE_INT);
        if ($id === false) {
            throw ApiException::notFound('not found');
        }

        return $id;
    }
}
