<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * An append-only ledger entry; the database rejects updates and deletes.
 *
 * @property int $id
 * @property int $account_id
 * @property string $type
 * @property int $amount
 * @property string|null $description
 */
class Transaction extends Model
{
    use SerializesDatesAsIso8601;

    public const TYPES = ['credit', 'debit'];

    public const SIGNED_AMOUNT = "CASE WHEN type = 'credit' THEN amount ELSE -amount END";

    const UPDATED_AT = null;

    // Keep microseconds, which the default 'Y-m-d H:i:s' would drop.
    protected $dateFormat = 'Y-m-d H:i:s.uP';

    protected $fillable = ['type', 'amount', 'description'];

    protected $visible = ['id', 'account_id', 'type', 'amount', 'description', 'created_at'];

    protected function casts(): array
    {
        return [
            'id' => 'integer',
            'account_id' => 'integer',
            'amount' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    public function account(): BelongsTo
    {
        return $this->belongsTo(Account::class);
    }
}
