<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Scope;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Accounts are provisioned in the database (db/init.sql owns the schema).
 *
 * @property int $id
 * @property string $name
 * @property int $balance
 */
class Account extends Model
{
    use SerializesDatesAsIso8601;

    public $timestamps = false;

    protected $visible = ['id', 'name', 'balance', 'created_at'];

    protected function casts(): array
    {
        return [
            'id' => 'integer',
            'balance' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    /** Adds the balance, always derived from the ledger: credits minus debits. */
    #[Scope]
    protected function withBalance(Builder $query): void
    {
        $query->addSelect([
            'balance' => Transaction::query()
                ->selectRaw('COALESCE(SUM('.Transaction::SIGNED_AMOUNT.'), 0)')
                ->whereColumn('transactions.account_id', 'accounts.id'),
        ]);
    }
}
