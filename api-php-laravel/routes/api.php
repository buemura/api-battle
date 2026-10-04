<?php

use App\Http\Controllers\AccountController;
use App\Http\Controllers\DocsController;
use App\Http\Controllers\TransactionController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => response('ok')->header('Content-Type', 'text/plain'));

Route::get('/docs', [DocsController::class, 'ui']);
Route::get('/openapi.yaml', [DocsController::class, 'spec']);

Route::get('/accounts', [AccountController::class, 'index']);
Route::get('/accounts/{id}', [AccountController::class, 'show']);
Route::get('/accounts/{accountId}/transactions', [TransactionController::class, 'index']);
Route::post('/accounts/{accountId}/transactions', [TransactionController::class, 'store']);

Route::get('/transactions/{id}', [TransactionController::class, 'show']);
