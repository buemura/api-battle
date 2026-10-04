<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class SecurityHeaders
{
    private const HEADERS = [
        'X-Content-Type-Options' => 'nosniff',
        'X-Frame-Options' => 'SAMEORIGIN',
        'Referrer-Policy' => 'no-referrer',
        'Strict-Transport-Security' => 'max-age=15552000; includeSubDomains',
    ];

    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        $response->headers->add(self::HEADERS);
        $response->headers->set('X-Request-Id', $request->header('X-Request-Id') ?: (string) Str::uuid());

        return $response;
    }
}
