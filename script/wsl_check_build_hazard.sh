#!/usr/bin/env bash
# Check whether the extra competition directories can influence the seekdb build.
set -u
cd "$HOME/seekdb" || exit 1
echo "=== directories ==="
ls -d amd competition 2>/dev/null
echo "=== source files under amd/ and competition/ ==="
find amd competition -name '*.cpp' -o -name '*.hip' -o -name '*.cc' 2>/dev/null | head -10
echo "=== does the root CMakeLists reference them? ==="
grep -n -i "amd\|competition" CMakeLists.txt 2>/dev/null | head -5
echo "(empty above means no reference)"
echo "=== subdirectory globbing in root CMakeLists ==="
grep -n "add_subdirectory" CMakeLists.txt 2>/dev/null | head -20
echo "=== C++ source glob patterns that could match ==="
grep -rn "GLOB" CMakeLists.txt cmake/*.cmake 2>/dev/null | head -10
exit 0