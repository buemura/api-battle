<?php

namespace App\Exceptions;

use RuntimeException;

/** An expected failure, rendered as {"error": "<message>"}. */
class ApiException extends RuntimeException
{
    public function __construct(public readonly int $status, string $message)
    {
        parent::__construct($message);
    }

    public static function badRequest(string $message): self
    {
        return new self(400, $message);
    }

    public static function notFound(string $message): self
    {
        return new self(404, $message);
    }

    public static function unprocessable(string $message): self
    {
        return new self(422, $message);
    }
}
