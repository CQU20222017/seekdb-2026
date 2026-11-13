#!/usr/bin/env bash
# Syntax-check one translation unit with the flags the real build uses.
set -u
SRC_REL="${1:?usage: wsl_syntax_check.sh <src/relative/file.cpp>}"
BUILD="$HOME/seekdb/build_release"
CXX="$HOME/seekdb/deps/3rd/usr/local/oceanbase/devtools/bin/clang++-17"

if [ ! -x "$CXX" ]; then echo "compiler missing"; exit 0; fi

# find a flags.make whose path matches the file's directory
DIR_PART=$(dirname "$SRC_REL")
FLAGS_FILE=""
for cand in "$BUILD"/src/$(echo "$DIR_PART" | sed 's|^src/||')/CMakeFiles/*.dir/flags.make; do
  [ -f "$cand" ] && FLAGS_FILE="$cand" && break
done
if [ -z "$FLAGS_FILE" ]; then
  for cand in "$BUILD"/src/oblib/CMakeFiles/*.dir/flags.make; do
    [ -f "$cand" ] && FLAGS_FILE="$cand" && break
  done
fi
echo "flags: ${FLAGS_FILE:-none}"
[ -z "$FLAGS_FILE" ] && exit 0

FLAGS=$(grep -h '^CXX_FLAGS' "$FLAGS_FILE" | sed 's/^CXX_FLAGS *= *//')
DEFS=$(grep -h '^CXX_DEFINES' "$FLAGS_FILE" | sed 's/^CXX_DEFINES *= *//')
INCS=$(grep -h '^CXX_INCLUDES' "$FLAGS_FILE" | sed 's/^CXX_INCLUDES *= *//')

cd "$HOME/seekdb" || exit 1
echo "=== syntax check $SRC_REL ==="
eval "\"$CXX\" -fsyntax-only $DEFS $INCS $FLAGS \"$SRC_REL\"" 2>&1 | head -25
echo "=== done (no output above means clean) ==="
exit 0