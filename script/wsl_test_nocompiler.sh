#!/usr/bin/env bash
# Simulate a container without g++/c++/hipcc and check that run.sh still passes.
set -u
mkdir -p /tmp/nocxx
for tool in python3 bash sh make; do
  p=$(command -v "$tool" 2>/dev/null) && ln -sf "$p" "/tmp/nocxx/$tool"
done
echo "=== tools visible in the stripped PATH ==="
ls /tmp/nocxx
echo
echo "=== run.sh with PATH=/tmp/nocxx ==="
cd /mnt/d/seekdb-2026/amd || exit 1
env -i PATH=/tmp/nocxx HOME="$HOME" bash run.sh --quick
echo "EXIT=$?"
exit 0