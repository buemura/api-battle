<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Account;
use App\Support\Pagination;
use App\Support\PathId;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AccountController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $pagination = Pagination::fromRequest($request);

        $accounts = $pagination->apply(Account::query()->withBalance()->orderBy('id'))->get();

        return response()->json($pagination->envelope($accounts, Account::query()->count()));
    }

    public function show(string $id): Account
    {
        return Account::query()->withBalance()->find(PathId::parse($id))
            ?? throw ApiException::notFound('account not found');
    }
}
