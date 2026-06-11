#!/usr/bin/env bash
# Live no-egress witness for sub-goal 07 (REQUIRED): run the DEFAULT-path chat (cloud opt-in OFF)
# and watch its real TCP connections with lsof. Assert NOTHING but loopback is contacted.
#
#   bash scripts/verify-chat-no-egress.sh
#
# Exit 0 only if every TCP peer the process contacts is loopback (127.0.0.1 / ::1 / localhost).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

BIN=/tmp/sp-noegress
swiftc app/Sources/ChatEngine.swift app/Sources/LLMSettings.swift app/Sources/SearchClient.swift \
  scripts/no-egress-runner.swift -o "$BIN" || { echo "FAIL: compile"; exit 1; }

"$BIN" >/dev/null 2>&1 &
PID=$!

peers=""
for _ in $(seq 1 20); do
  # -a ANDs the filters (without it, lsof ORs -p and -i and lists every process's TCP).
  c=$(lsof -nP -a -p "$PID" -iTCP 2>/dev/null | awk 'NR>1 && /->/{print $9}')
  [ -n "$c" ] && peers+="$c"$'\n'
  sleep 0.3
done
wait "$PID" 2>/dev/null || true

# peer = the address after "->", port stripped
peerlist=$(printf '%s\n' "$peers" | grep -oE '\->[^ ]+' | sed -E 's/^->//; s/:[0-9]+$//' | sort -u | sed '/^$/d')
echo "peer addresses observed:"; printf '  %s\n' ${peerlist:-"(none captured this run)"}

nonloop=$(printf '%s\n' "$peerlist" | grep -vE '^(127\.0\.0\.1|\[::1\]|::1|localhost)$' || true)
if [ -n "$nonloop" ]; then
  echo "FAIL: non-loopback egress detected with cloud OFF:"; printf '  %s\n' "$nonloop"; exit 1
fi

loop=$(printf '%s\n' "$peerlist" | grep -cE '^(127\.0\.0\.1|\[::1\]|::1|localhost)$' || true)
echo "OK: cloud OFF default-path chat made NO non-loopback connection (loopback peers seen: ${loop:-0})"
