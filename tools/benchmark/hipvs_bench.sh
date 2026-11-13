#!/usr/bin/env bash
# Copyright (c) 2025 OceanBase
# Licensed under the Apache License, Version 2.0 (see ../../LICENSE).
#
# AMD hipVS HNSW build benchmark.
#
# Uses only bash builtins and python3 so it also runs inside a minimal container
# (no coreutils beyond what bash provides).
#
#   bash tools/benchmark/hipvs_bench.sh
#   HIPVS_ROWS=2000 HIPVS_DIM=128 bash tools/benchmark/hipvs_bench.sh
#
# Environment variables (all optional):
#   HIPVS_ROWS / HIPVS_DIM / HIPVS_QUERIES / HIPVS_RUNS
#   HIPVS_OUTPUT / HIPVS_JSON
set -uo pipefail

# resolve the script directory without dirname: BASH_SOURCE may be a bare file name
_src="${BASH_SOURCE[0]}"
if [ "${_src#*/}" != "$_src" ]; then _dir="${_src%/*}"; else _dir="."; fi
HERE="$(cd "$_dir" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BENCH="$ROOT/amd/bench/bench_build.py"

ROWS="${HIPVS_ROWS:-800}"
DIM="${HIPVS_DIM:-64}"
QUERIES="${HIPVS_QUERIES:-50}"
RUNS="${HIPVS_RUNS:-3}"
OUTPUT="${HIPVS_OUTPUT:-$ROOT/amd/bench/report.md}"
JSON="${HIPVS_JSON:-$ROOT/amd/bench/result.json}"

PY=""
for cand in python3 python; do
  if command -v "$cand" > /dev/null 2>&1; then PY="$cand"; break; fi
done
if [ -z "$PY" ]; then
  echo "[FAIL] python3 is required"
  exit 1
fi
if [ ! -f "$BENCH" ]; then
  echo "[FAIL] benchmark driver not found: $BENCH"
  exit 1
fi

echo "=== hipVS HNSW build benchmark ==="
echo "rows=$ROWS dim=$DIM queries=$QUERIES runs=$RUNS"

"$PY" "$BENCH" --n "$ROWS" --d "$DIM" --queries "$QUERIES" --runs "$RUNS" \
    --out "$OUTPUT" --json "$JSON"
RC=$?
if [ "$RC" -ne 0 ]; then
  echo "[FAIL] benchmark exited with $RC"
  exit "$RC"
fi

echo
echo "=== summary ==="
"$PY" - "$JSON" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    r = json.load(f)

con = r["conclusion"]
print("build_median_ms:      %.1f" % con["cpu_median_ms"])
print("recall_at_k:          %.4f" % r["recall"]["value"])
print("graph_avg_degree:     %.2f" % r["graph"]["avg_degree"])
print("graph_isolated_nodes: %d" % r["graph"]["isolated_nodes"])
print("gpu_path_status:      %s" % r["gpu_path"]["status"])
print("gpu_model_total_ms:   %.1f (cost model, not measured)" % con["gpu_model_ms"])
print("gpu_model_speedup:    %.2fx (cost model, not measured)" % con["model_speedup"])
PY

echo "[OK] hipvs benchmark finished"
exit 0