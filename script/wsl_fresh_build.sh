#!/usr/bin/env bash
# Reproduce what the evaluation platform does: clone the repository fresh and build it
# from scratch (reusing the already downloaded third party dependencies via symlink).
set -uo pipefail

WORK=/tmp/fresh_clone
BRANCH="${1:-2026-competition}"
LOG=/tmp/fresh_build.log

rm -rf "$WORK"
echo "=== clone ($BRANCH) ===" | tee "$LOG"
git clone --depth 1 --branch "$BRANCH" "$HOME/seekdb" "$WORK" >> "$LOG" 2>&1 || {
  echo "[FAIL] clone failed"; tail -n 20 "$LOG"; exit 1;
}
echo "clone ok: $(du -sh "$WORK" 2>/dev/null | cut -f1)" | tee -a "$LOG"

# reuse the dependency tree that is already unpacked
if [ -d "$HOME/seekdb/deps/3rd" ] && [ ! -d "$WORK/deps/3rd" ]; then
  echo "linking deps" | tee -a "$LOG"
  rm -rf "$WORK/deps"
  ln -s "$HOME/seekdb/deps" "$WORK/deps"
fi

cd "$WORK" || exit 1
echo "=== build.sh release --make -j4 ===" | tee -a "$LOG"
START=$(date +%s)
./build.sh release --make -j4 >> "$LOG" 2>&1
RC=$?
END=$(date +%s)
echo "build exit=$RC elapsed=$((END - START))s" | tee -a "$LOG"
if [ "$RC" -ne 0 ]; then
  echo "=== last 40 lines of the log ==="
  tail -n 40 "$LOG"
  exit 1
fi
echo "=== binary ===" | tee -a "$LOG"
ls -l "$WORK/build_release/src/observer/seekdb" | tee -a "$LOG"
echo "[OK] clean clone builds"
exit 0