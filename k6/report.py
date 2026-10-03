#!/usr/bin/env python3
"""Build a Gatling-style HTML report from a k6 run.

Usage:
    python3 k6/report.py <summary.json> <raw.csv[.gz]> <out.html> [title]

Inputs come from:
    k6 run --summary-export summary.json --out csv=raw.csv.gz load-test.js
"""
import csv
import gzip
import json
import math
import re
import statistics
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone

# Collapse concrete URLs into route templates so ids don't explode the table.
ROUTES = [
    (re.compile(r"/accounts/\d+/transactions(\?.*)?$"), "/accounts/{id}/transactions"),
    (re.compile(r"/accounts/\d+$"), "/accounts/{id}"),
    (re.compile(r"/transactions/\d+$"), "/transactions/{id}"),
    (re.compile(r"/accounts(\?.*)?$"), "/accounts"),
]

# Response time ranges (ms); the upper bound mirrors the p(95)<200 threshold.
RANGE_LOW, RANGE_HIGH = 50, 200


def route(method, url):
    path = re.sub(r"^https?://[^/]+", "", url)
    for pattern, name in ROUTES:
        if pattern.search(path):
            return f"{method} {name}"
    return f"{method} {path.split('?')[0]}"


def pct(sorted_vals, p):
    if not sorted_vals:
        return 0.0
    k = (len(sorted_vals) - 1) * p / 100
    lo, hi = math.floor(k), math.ceil(k)
    return sorted_vals[lo] + (sorted_vals[hi] - sorted_vals[lo]) * (k - lo)


def stats(durations, ok, ko, seconds):
    d = sorted(durations)
    return {
        "total": ok + ko,
        "ok": ok,
        "ko": ko,
        "rps": (ok + ko) / seconds if seconds else 0,
        "min": d[0] if d else 0,
        "p50": pct(d, 50),
        "p75": pct(d, 75),
        "p95": pct(d, 95),
        "p99": pct(d, 99),
        "max": d[-1] if d else 0,
        "mean": statistics.fmean(d) if d else 0,
        "std": statistics.pstdev(d) if len(d) > 1 else 0,
    }


def nice_step(raw):
    exp = 10 ** math.floor(math.log10(raw))
    for m in (1, 2, 2.5, 5, 10):
        if raw <= m * exp:
            return m * exp
    return 10 * exp


def main():
    summary_path, raw_path, out_path = sys.argv[1:4]
    title = sys.argv[4] if len(sys.argv) > 4 else "k6 load test"

    summary = json.load(open(summary_path))
    opener = gzip.open if raw_path.endswith(".gz") else open

    all_durations = []
    per_route = defaultdict(lambda: {"d": [], "ok": 0, "ko": 0})
    per_sec = defaultdict(lambda: {"d": [], "ok": 0, "ko": 0})
    vus_by_sec = {}
    statuses = Counter()
    checks = defaultdict(lambda: [0, 0])

    with opener(raw_path, "rt", newline="") as f:
        for row in csv.DictReader(f):
            metric = row["metric_name"]
            ts = int(row["timestamp"])
            if metric == "http_req_duration":
                v = float(row["metric_value"])
                ok = row["expected_response"] == "true"
                all_durations.append(v)
                for bucket in (per_route[route(row["method"], row["name"])], per_sec[ts]):
                    bucket["d"].append(v)
                    bucket["ok" if ok else "ko"] += 1
                statuses[(route(row["method"], row["name"]), row["status"] or "error")] += 1
            elif metric == "vus":
                vus_by_sec[ts] = max(vus_by_sec.get(ts, 0), int(float(row["metric_value"])))
            elif metric == "checks":
                checks[row["check"]][0 if float(row["metric_value"]) else 1] += 1

    start, end = min(per_sec), max(per_sec)
    # k6's own duration (count / rate); the CSV's whole-second timestamps
    # can span one extra partial second at either end.
    reqs = summary["metrics"].get("http_reqs", {})
    seconds = reqs["count"] / reqs["rate"] if reqs.get("rate") else end - start + 1
    ok_total = sum(b["ok"] for b in per_sec.values())
    ko_total = sum(b["ko"] for b in per_sec.values())

    timeline = []
    for ts in range(start, end + 1):
        b = per_sec.get(ts, {"d": [], "ok": 0, "ko": 0})
        d = sorted(b["d"])
        timeline.append({
            "t": ts - start,
            "ok": b["ok"],
            "ko": b["ko"],
            "vus": vus_by_sec.get(ts, 0),
            "p50": pct(d, 50),
            "p95": pct(d, 95),
            "p99": pct(d, 99),
        })

    # Histogram: ~50 bins up to p99.5, the long tail folded into a last bin.
    sorted_all = sorted(all_durations)
    cap = pct(sorted_all, 99.5)
    step = nice_step(cap / 50)
    nbins = math.ceil(cap / step)
    bins = [0] * (nbins + 1)
    for v in all_durations:
        bins[min(int(v // step), nbins)] += 1
    histogram = {"step": step, "bins": bins}

    ranges = {
        "fast": sum(1 for v in all_durations if v < RANGE_LOW),
        "mid": sum(1 for v in all_durations if RANGE_LOW <= v < RANGE_HIGH),
        "slow": sum(1 for v in all_durations if v >= RANGE_HIGH),
        "ko": ko_total,
    }
    # Failed requests are counted in "ko" only, not in a latency bucket.
    if ko_total:
        ranges["fast"] = max(ranges["fast"] - ko_total, 0)

    m = summary["metrics"]
    thresholds = []
    for name, metric in m.items():
        for expr, failed in (metric.get("thresholds") or {}).items():
            thresholds.append({"metric": name, "expr": expr, "passed": not failed})

    data = {
        "title": title,
        "startedAt": datetime.fromtimestamp(start, timezone.utc).isoformat(),
        "seconds": seconds,
        "global": stats(all_durations, ok_total, ko_total, seconds),
        "routes": sorted(
            ({"name": k, **stats(v["d"], v["ok"], v["ko"], seconds)} for k, v in per_route.items()),
            key=lambda r: -r["total"],
        ),
        "timeline": timeline,
        "histogram": histogram,
        "ranges": {**ranges, "low": RANGE_LOW, "high": RANGE_HIGH},
        "statuses": sorted(
            ({"route": r, "status": s, "count": c} for (r, s), c in statuses.items()),
            key=lambda x: (x["route"], x["status"]),
        ),
        "checks": [{"name": k, "passes": v[0], "fails": v[1]} for k, v in checks.items()],
        "thresholds": thresholds,
        "iterations": m.get("iterations", {}).get("count", 0),
        "vusMax": m.get("vus_max", {}).get("max", max(vus_by_sec.values(), default=0)),
        "dataReceived": m.get("data_received", {}).get("count", 0),
        "dataSent": m.get("data_sent", {}).get("count", 0),
    }

    template = open(__file__.replace("report.py", "report-template.html")).read()
    html = template.replace("__TITLE__", title).replace("__DATA__", json.dumps(data, separators=(",", ":")))
    open(out_path, "w").write(html)
    print(f"wrote {out_path}: {data['global']['total']} requests over {seconds:.1f}s, {data['global']['rps']:.1f} req/s")


if __name__ == "__main__":
    main()
