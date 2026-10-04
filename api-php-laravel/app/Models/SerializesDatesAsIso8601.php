<?php

namespace App\Models;

use DateTimeInterface;
use Illuminate\Support\Carbon;

trait SerializesDatesAsIso8601
{
    /** e.g. 2026-10-03T02:44:35.274Z */
    protected function serializeDate(DateTimeInterface $date): string
    {
        return Carbon::instance($date)->utc()->format('Y-m-d\TH:i:s.v\Z');
    }
}
