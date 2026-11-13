#!/usr/bin/env bash
# Bring up a standalone seekdb instance for the deployment task and print its telemetry id.
# Uses a dedicated port/base-dir so it never collides with a test instance.
set -uo pipefail

PORT="${PORT:-2891}"
RUN_DIR="${RUN_DIR:-$HOME/seekdb_deploy}"
BIN="$HOME/seekdb/build_release/src/observer/seekdb"
LOG="$RUN_DIR/seekdb.log"

port_open() {
  python3 - "$1" <<'PY'
import socket, sys
s = socket.socket(); s.settimeout(1)
try:
    s.connect(("127.0.0.1", int(sys.argv[1]))); sys.exit(0)
except OSError:
    sys.exit(1)
PY
}

if [ ! -x "$BIN" ]; then
  echo "ERROR: binary not found at $BIN"
  exit 1
fi

if port_open "$PORT"; then
  echo "instance already listening on $PORT"
else
  echo "=== starting seekdb on $PORT (base dir $RUN_DIR) ==="
  rm -rf "$RUN_DIR"
  mkdir -p "$RUN_DIR"
  nohup "$BIN" --nodaemon --port "$PORT" --base-dir "$RUN_DIR" --data-dir "$RUN_DIR/store" \
      > "$LOG" 2>&1 &
  echo $! > "$RUN_DIR/seekdb.pid"
  echo "pid=$(cat "$RUN_DIR/seekdb.pid")"
fi

echo "=== waiting for SQL layer ==="
for i in $(seq 1 90); do
  if python3 - "$PORT" <<'PY'
import sys
try:
    import pymysql
except ImportError:
    sys.exit(2)
try:
    conn = pymysql.connect(host="127.0.0.1", port=int(sys.argv[1]), user="root", password="",
                           connect_timeout=3, read_timeout=5, write_timeout=5)
    with conn.cursor() as cur:
        cur.execute("select 1")
        cur.fetchone()
    conn.close()
    sys.exit(0)
except Exception:
    sys.exit(1)
PY
  then
    echo "SQL ready after ~$((i * 2))s"
    break
  fi
  sleep 2
done

echo "=== instance info ==="
python3 - "$PORT" <<'PY'
import sys
import pymysql
conn = pymysql.connect(host="127.0.0.1", port=int(sys.argv[1]), user="root", password="",
                       connect_timeout=5, read_timeout=10, write_timeout=5)
with conn.cursor() as cur:
    cur.execute("select version()")
    print("version:", cur.fetchone()[0])
    cur.execute("select 1 + 1")
    print("sql_ok:", cur.fetchone()[0])
conn.close()
PY

echo "=== telemetry ==="
T="$RUN_DIR/run/telemetry.json"
if [ -f "$T" ]; then
  python3 -c "import json; print('telemetry_id=' + json.load(open('$T'))['content']['id'])"
else
  echo "telemetry.json not found at $T"
  find "$RUN_DIR" -name telemetry.json -maxdepth 4 2>/dev/null
fi
exit 0