<?php

use App\Exceptions\ApiException;
use App\Http\Middleware\SecurityHeaders;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\MethodNotAllowedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        apiPrefix: '',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->append(SecurityHeaders::class);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Expected failures are part of the contract, not incidents.
        $exceptions->dontReport([ApiException::class]);

        // Every error is rendered as {"error": "<message>"}.
        $exceptions->render(function (Throwable $e) {
            [$status, $message] = match (true) {
                $e instanceof ApiException => [$e->status, $e->getMessage()],
                $e instanceof ValidationException => [400, $e->validator->errors()->first()],
                $e instanceof NotFoundHttpException => [404, 'not found'],
                $e instanceof MethodNotAllowedHttpException => [405, 'method not allowed'],
                $e instanceof HttpExceptionInterface => [$e->getStatusCode(), $e->getMessage() ?: 'request failed'],
                default => [500, 'internal server error'],
            };

            return response()->json(['error' => $message], $status);
        });
    })->create();
