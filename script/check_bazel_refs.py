"""Check that every file referenced by an in-tree BUILD.bazel actually exists.

The round-three fulltext merge touched src/sql/BUILD.bazel and src/share/BUILD.bazel;
a stale reference there breaks a fresh bazel build while an incremental cmake build
stays green. This script reports any dangling srcs/hdrs entry.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATTERN = re.compile(r'"([^"]+\.(?:cpp|cc|c|h|hpp))"')
SKIP_DIRS = {".git", "build_release", "deps", "rust/target"}

missing = []
checked = 0
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
    if "BUILD.bazel" not in filenames and "BUILD" not in filenames:
        continue
    for name in ("BUILD.bazel", "BUILD"):
        path = os.path.join(dirpath, name)
        if not os.path.exists(path):
            continue
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError:
            continue
        for ref in PATTERN.findall(text):
            if ref.startswith("//") or ref.startswith("@"):
                continue
            target = os.path.normpath(os.path.join(dirpath, ref))
            checked += 1
            if not os.path.exists(target):
                missing.append((os.path.relpath(path, ROOT), ref))

print("references checked:", checked)
if not missing:
    print("RESULT: OK (no dangling references)")
    sys.exit(0)

print("RESULT: %d dangling reference(s)" % len(missing))
seen = set()
for build_file, ref in missing:
    key = (build_file, ref)
    if key in seen:
        continue
    seen.add(key)
    print("  %-45s -> %s" % (build_file, ref))
sys.exit(1)