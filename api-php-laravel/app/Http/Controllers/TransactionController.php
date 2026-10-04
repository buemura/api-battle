<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Account;
use App\Models\Transaction;
use App\Support\Pagination;
use App\Support\PathId;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use JsonException;

class TransactionController extends Controller
{
    private const TYPE_ERROR = "'type' must be either 'credit' or 'debit'";

    private const AMOUNT_ERROR = "'amount' must be a positive integer (minor units, e.g. cents)";

    private const DESCRIPTION_ERROR = "'description' must be a string of at most 255 characters";

    public function index(Request $request, string $accountId): JsonResponse
    {
        $pagination = Pagination::fromRequest($request);

        $account = Account::query()->withCount('transactions')->find(PathId::parse($accountId))
            ?? throw ApiException::notFound('account not found');

        $transactions = $pagination->apply($account->transactions()->orderByDesc('id'))->get();

        return response()->json($pagination->envelope($transactions, $account->transactions_count));
    }

    public function store(Request $request, string $accountId): JsonResponse
    {
        $id = PathId::parse($accountId);
        $input = $this->validated($request);

        $transaction = DB::transaction(function () use ($id, $input) {
            // Lock the account row so concurrent debits can't overdraw it.
            $account = Account::query()->lockForUpdate()->find($id, ['id'])
                ?? throw ApiException::notFound('account not found');

            if ($input['type'] === 'debit') {
                $balance = (int) $account->transactions()->sum(DB::raw(Transaction::SIGNED_AMOUNT));
                if ($balance < $input['amount']) {
                    throw ApiException::unprocessable('insufficient funds');
                }
            }

            return $account->transactions()->create($input);
        });

        return response()->json($transaction, 201);
    }

    public function show(string $id): Transaction
    {
        return Transaction::query()->find(PathId::parse($id))
            ?? throw ApiException::notFound('transaction not found');
    }

    /**
     * Parses the body as JSON whatever its content type (Laravel would silently
     * treat malformed JSON as empty input) and validates it field by field.
     *
     * @return array{type: string, amount: int, description: ?string}
     */
    private function validated(Request $request): array
    {
        try {
            $body = json_decode($request->getContent(), false, 64, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            throw ApiException::badRequest('request body must be JSON');
        }
        if (! $body instanceof \stdClass) {
            throw ApiException::badRequest('request body must be a JSON object');
        }
        $body = (array) $body;

        $data = Validator::make($body, [
            'type' => ['bail', 'required', 'string', Rule::in(Transaction::TYPES)],
            'amount' => ['bail', 'required', 'integer:strict', 'min:1', 'max:9007199254740991'],
            'description' => ['bail', 'nullable', 'string', 'max:255'],
        ], [
            'type.*' => self::TYPE_ERROR,
            'amount.*' => self::AMOUNT_ERROR,
            'description.*' => self::DESCRIPTION_ERROR,
        ])->validate();

        return [
            'type' => $data['type'],
            'amount' => $data['amount'],
            'description' => ($data['description'] ?? '') === '' ? null : $data['description'],
        ];
    }
}
