#!/usr/bin/env bash
# Verify every documented entry point of the AMD submission works.
set -u
cd /mnt/d/seekdb-2026/amd || exit 1
fail=0

echo "=== make test ==="
if make test > /tmp/amd_mt.log 2>&1; then tail -n 3 /tmp/amd_mt.log; else echo "[FAIL] make test"; tail -n 15 /tmp/amd_mt.log; fail=1; fi

echo "=== make bench ==="
if make bench > /tmp/amd_mb.log 2>&1; then tail -n 2 /tmp/amd_mb.log; else echo "[FAIL] make bench"; tail -n 15 /tmp/amd_mb.log; fail=1; fi

echo "=== bash run.sh --quick ==="
if bash run.sh --quick > /tmp/amd_rs.log 2>&1; then tail -n 4 /tmp/amd_rs.log; else echo "[FAIL] run.sh"; tail -n 15 /tmp/amd_rs.log; fail=1; fi

echo "=== python3 bench/bench_build.py (from repo root) ==="
cd /mnt/d/seekdb-2026 || exit 1
if python3 amd/bench/bench_build.py > /tmp/amd_pb.log 2>&1; then tail -n 2 /tmp/amd_pb.log; else echo "[FAIL] bench from root"; tail -n 15 /tmp/amd_pb.log; fail=1; fi

echo "=== python3 -m unittest (from repo root) ==="
if python3 -m unittest discover -s amd/tests > /tmp/amd_ut.log 2>&1; then tail -n 3 /tmp/amd_ut.log; else echo "[FAIL] unittest from root"; tail -n 15 /tmp/amd_ut.log; fail=1; fi

echo
if [ "$fail" = "0" ]; then echo "ALL ENTRY POINTS OK"; else echo "SOME ENTRY POINTS FAILED"; fi
exit $fail