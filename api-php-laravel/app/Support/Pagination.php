<?php

namespace App\Support;

use App\Exceptions\ApiException;
use Illuminate\Contracts\Database\Query\Builder;
use Illuminate\Http\Request;

final readonly class Pagination
{
    private const DEFAULT_PAGE_SIZE = 20;

    private const MAX_PAGE_SIZE = 100;

    private const MAX_PAGE = 4294967295;

    public const ERROR = "'page' must be >= 1 and 'page_size' must be between 1 and 100";

    private function __construct(public int $page, public int $pageSize) {}

    /** Missing or empty values fall back to the defaults; anything else must be a plain integer in range. */
    public static function fromRequest(Request $request): self
    {
        $page = self::param($request, 'page', 1);
        $pageSize = self::param($request, 'page_size', self::DEFAULT_PAGE_SIZE);

        if ($page < 1 || $page > self::MAX_PAGE || $pageSize < 1 || $pageSize > self::MAX_PAGE_SIZE) {
            throw ApiException::badRequest(self::ERROR);
        }

        return new self($page, $pageSize);
    }

    private static function param(Request $request, string $key, int $default): int
    {
        $raw = $request->query($key);
        if ($raw === null || $raw === '') {
            return $default;
        }
        // Digits only; cap the length so huge values can't overflow to float.
        if (! is_string($raw) || ! preg_match('/^\d{1,10}$/', $raw)) {
            throw ApiException::badRequest(self::ERROR);
        }

        return (int) $raw;
    }

    public function apply(Builder $query): Builder
    {
        return $query->limit($this->pageSize)->offset(($this->page - 1) * $this->pageSize);
    }

    /** The paginated response envelope. */
    public function envelope(iterable $data, int $total): array
    {
        return ['data' => $data, 'page' => $this->page, 'page_size' => $this->pageSize, 'total' => $total];
    }
}
