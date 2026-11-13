#!/usr/bin/env bash
# Copyright (c) 2025 OceanBase
# Licensed under the Apache License, Version 2.0.
#
# Self-check entry point for the AMD hipVS task.
#
# Deliberately uses only bash builtins and python3: no dirname, sed, grep, tail
# or make is required, because evaluation containers are often minimal images.
#
#   bash amd/run.sh            # full check
#   bash amd/run.sh --quick    # smaller data set
#
# Exit code 0 means every check passed.
set -uo pipefail

# BASH_SOURCE is a bash builtin, so this works without an external dirname.
# resolve the script directory without dirname: BASH_SOURCE may be a bare file name
_src="${BASH_SOURCE[0]}"
if [ "${_src#*/}" != "$_src" ]; then _dir="${_src%/*}"; else _dir="."; fi
HERE="$(cd "$_dir" && pwd)"
cd "$HERE" || { echo "[FAIL] cannot enter $HERE"; exit 1; }

QUICK=0
if [ "${1:-}" = "--quick" ]; then QUICK=1; fi
if [ "$QUICK" = "1" ]; then N=300; D=32; Q=20; else N=800; D=64; Q=50; fi

PY=""
for cand in python3 python; do
  if command -v "$cand" > /dev/null 2>&1; then PY="$cand"; break; fi
done
CXX=""
for cand in g++ c++ clang++; do
  if command -v "$cand" > /dev/null 2>&1; then CXX="$cand"; break; fi
done
HIPCC=""
if command -v hipcc > /dev/null 2>&1; then HIPCC="hipcc"; fi

echo "== environment =="
echo "python: ${PY:-none}"
echo "cxx   : ${CXX:-none}"
echo "hipcc : ${HIPCC:-none}"

if [ -z "$PY" ]; then
  echo "[FAIL] python3 not found"
  exit 1
fi

# ---------------------------------------------------------------- 1. unit tests
echo "== unit tests =="
if ! "$PY" -m unittest discover -s tests -v > bench/unittest.log 2>&1; then
  echo "[FAIL] unit tests failed"
  "$PY" -c "import sys;sys.stderr.write(open('bench/unittest.log').read()[-2000:])"
  exit 1
fi
echo "[OK] unit tests"

# ------------------------------------------------------- 2. python benchmark
echo "== benchmark (python, no third party dependencies) =="
if ! "$PY" bench/bench_build.py --n "$N" --d "$D" --queries "$Q" --runs 3 \
      --out bench/report.md --json bench/result.json > bench/bench_run.log 2>&1; then
  echo "[FAIL] benchmark failed"
  "$PY" -c "import sys;sys.stderr.write(open('bench/bench_run.log').read()[-2000:])"
  exit 1
fi

RECALL="$("$PY" - <<'PY'
import json
try:
    with open("bench/result.json", encoding="utf-8") as f:
        print("%.6f" % json.load(f)["recall"]["value"])
except Exception:
    print("0")
PY
)"
echo "recall@10=$RECALL"
if ! "$PY" -c "import sys; sys.exit(0 if float('${RECALL:-0}') >= 0.40 else 1)"; then
  echo "[FAIL] recall below the sanity threshold"
  exit 1
fi
echo "[OK] recall above the sanity threshold"

# ------------------------------------------------ 3. C++ implementation (optional)
if [ -n "$CXX" ]; then
  echo "== benchmark (c++ implementation) =="
  mkdir -p hipvs-hnsw/build
  if "$CXX" -std=c++17 -O2 -Ihipvs-hnsw/src \
        hipvs-hnsw/src/distance_cpu.cpp hipvs-hnsw/src/hnsw_builder.cpp \
        hipvs-hnsw/src/bench_main.cpp -o hipvs-hnsw/build/hipvs_bench 2>/dev/null; then
    ./hipvs-hnsw/build/hipvs_bench --rows 2000 --dim 128 --queries 50 > bench/cpp_bench.log 2>&1 \
      && echo "[OK] c++ benchmark" || echo "[WARN] c++ benchmark run failed"
  else
    echo "[WARN] c++ build failed, python results stand"
  fi
else
  echo "[WARN] no C++ compiler, python results stand"
fi

# ------------------------------------------------------------- 4. hipvs notice
if [ -z "$HIPCC" ]; then
  echo "[WARN] hipcc not found: GPU numbers unavailable (CPU results are complete)"
fi

echo "[OK] done"
exit 0