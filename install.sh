#!/usr/bin/env bash
# install.sh -- take a Mac from nothing to a running, hardened, redacted screenpipe capture.
# The one step everyone trips on is the per-binary macOS Screen Recording grant: this script
# triggers/verifies it against the EXACT binary the LaunchAgent runs, in the FOREGROUND (where
# the prompt actually shows), and fails LOUDLY if denied instead of letting launchd hang silently.
#
# Idempotent. Env-overridable so a second, isolated instance can be installed for self-test:
#   SCREENPIPE_MENUBAR_PREFIX      install root        (default ~/.local)
#   SCREENPIPE_MENUBAR_LABEL       LaunchAgent label   (default com.screenpipe.capture)
#   SCREENPIPE_MENUBAR_CONFIG_DIR  config dir          (default ~/.config/screenpipe-menubar)
#   SCREENPIPE_MENUBAR_DATA_DIR    screenpipe data dir (default ~/.screenpipe)
#   SCREENPIPE_MENUBAR_PORT        API port            (default 3030)
set -euo pipefail

PREFIX="${SCREENPIPE_MENUBAR_PREFIX:-$HOME/.local}"
LABEL="${SCREENPIPE_MENUBAR_LABEL:-com.screenpipe.capture}"
CONFIG_DIR="${SCREENPIPE_MENUBAR_CONFIG_DIR:-$HOME/.config/screenpipe-menubar}"
DATA_DIR="${SCREENPIPE_MENUBAR_DATA_DIR:-$HOME/.screenpipe}"
PORT="${SCREENPIPE_MENUBAR_PORT:-3030}"
LANGUAGES="${SCREENPIPE_MENUBAR_LANGUAGES:-english}"
RETENTION="${SCREENPIPE_MENUBAR_RETENTION_DAYS:-14}"
GRACE="${SCREENPIPE_MENUBAR_GRACE:-45}"   # seconds to wait for the API to bind

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$PREFIX/bin"
SHARE_DIR="$PREFIX/share/screenpipe-menubar"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
CONFIG="$CONFIG_DIR/config"
UID_="$(id -u)"
LOG_OUT="$DATA_DIR/launchd.out.log"
LOG_ERR="$DATA_DIR/launchd.err.log"
HEALTH="http://localhost:$PORT/health"

log()  { printf '  %s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

api_up() { curl -fsS --max-time 3 "$HEALTH" >/dev/null 2>&1; }

resolve_sp_bin() {
  local direct="$HOME/.cache/.bun/install/global/node_modules/@screenpipe/cli-darwin-arm64/bin/screenpipe"
  [ -x "$direct" ] && { echo "$direct"; return; }
  command -v screenpipe 2>/dev/null && return
  for p in "$HOME/.cache/.bun/bin/screenpipe" "$HOME/.bun/bin/screenpipe"; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
  return 1
}

step "Preflight: locate the screenpipe CLI"
SP_BIN="$(resolve_sp_bin)" || die "screenpipe CLI not found.
Install it first (see https://github.com/mediar-ai/screenpipe), then re-run.
This installer does NOT pipe a remote script to your shell."
log "found: $SP_BIN"
[ "$(uname -s)" = "Darwin" ] || die "macOS only (uses launchd + Screen Recording TCC)."

step "Install backend to $BIN_DIR + patterns to $SHARE_DIR"
mkdir -p "$BIN_DIR" "$SHARE_DIR/patterns" "$DATA_DIR" "$CONFIG_DIR" "$(dirname "$PLIST")"
install -m 0755 "$SELF/bin/screenpipe-capture" "$BIN_DIR/screenpipe-capture"
install -m 0755 "$SELF/bin/screenpipe-ctl"     "$BIN_DIR/screenpipe-ctl"
install -m 0755 "$SELF/bin/scrub-elements.py"  "$BIN_DIR/scrub-elements.py"
install -m 0644 "$SELF/patterns/secrets.json"        "$SHARE_DIR/patterns/secrets.json"
install -m 0644 "$SELF/patterns/bip39-english.txt"   "$SHARE_DIR/patterns/bip39-english.txt"
log "installed screenpipe-capture, screenpipe-ctl, scrub-elements.py"

step "Render config: $CONFIG"
if [ -f "$CONFIG" ]; then
  log "exists, keeping it (edit by hand or delete to re-render)"
else
  cat > "$CONFIG" <<EOF
# screenpipe-menubar config (rendered by install.sh). Sourced by screenpipe-capture.
SCREENPIPE_RETENTION_DAYS=$RETENTION
SCREENPIPE_LANGUAGES="$LANGUAGES"
SCREENPIPE_EXTRA_IGNORED_WINDOWS=""
SCREENPIPE_PATTERNS_DIR="$SHARE_DIR/patterns"
SCREENPIPE_PORT=$PORT
SCREENPIPE_DATA_DIR="$DATA_DIR"
EOF
  log "wrote retention=$RETENTION langs=$LANGUAGES port=$PORT data=$DATA_DIR"
fi

step "Render LaunchAgent: $PLIST"
sed -e "s|__LABEL__|$LABEL|g" \
    -e "s|__PROGRAM__|$BIN_DIR/screenpipe-capture|g" \
    -e "s|__CONFIG__|$CONFIG|g" \
    -e "s|__STDOUT__|$LOG_OUT|g" \
    -e "s|__STDERR__|$LOG_ERR|g" \
    "$SELF/deploy/com.screenpipe.capture.plist.template" > "$PLIST"
# Guard: the template must not leak a hardcoded home; ProgramArguments[0] is bare-name.
grep -q "$BIN_DIR/screenpipe-capture" "$PLIST" || die "plist render failed (program path)"
log "label=$LABEL program=$BIN_DIR/screenpipe-capture (BTM-friendly bare-name)"

step "Screen Recording grant (the per-binary gate)"
if api_up; then
  log "an instance already answers $HEALTH; assuming the binary is granted (idempotent path)"
else
  log "spinning the capture binary in the foreground to trigger/verify the grant..."
  log "if macOS shows a Screen Recording prompt, click Allow (then re-run if needed)."
  SCREENPIPE_MENUBAR_CONFIG="$CONFIG" "$BIN_DIR/screenpipe-capture" >"$LOG_OUT" 2>"$LOG_ERR" &
  fg_pid=$!
  granted=0
  for _ in $(seq 1 "$GRACE"); do
    if ! kill -0 "$fg_pid" 2>/dev/null; then break; fi   # process died -> see log
    if api_up; then granted=1; break; fi
    sleep 1
  done
  kill "$fg_pid" 2>/dev/null || true
  wait "$fg_pid" 2>/dev/null || true
  if [ "$granted" -ne 1 ]; then
    die "capture did not bind the API within ${GRACE}s.
This is the classic per-binary Screen Recording denial: the grant is per BINARY, and this
exact binary is not granted, so ScreenCaptureKit blocks at startup (no prompt under launchd).
Fix:
  1. Open System Settings > Privacy & Security > Screen Recording.
  2. Add / enable:  $SP_BIN
  3. Re-run ./install.sh.
Startup log tail ($LOG_ERR):
$(tail -n 8 "$LOG_ERR" 2>/dev/null || echo '  (no log)')"
  fi
  log "grant OK: API bound within grace, screen capture is permitted."
fi

step "Bootstrap the LaunchAgent (KeepAlive 24/7 capture)"
launchctl bootout "gui/$UID_/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_" "$PLIST"
launchctl kickstart "gui/$UID_/$LABEL" 2>/dev/null || true

step "Verify: poll $HEALTH"
ok=0
for _ in $(seq 1 "$GRACE"); do
  if api_up; then ok=1; break; fi
  sleep 1
done
[ "$ok" -eq 1 ] || die "agent did not come up healthy within ${GRACE}s. Check: launchctl print gui/$UID_/$LABEL"
msg="$(curl -fsS --max-time 3 "$HEALTH" 2>/dev/null)"
log "API healthy. /health says:"
printf '%s\n' "$msg" | sed 's/^/      /' | head -c 400; echo

cat <<EOF

Done. Hardened screenpipe capture is running under launchd ($LABEL).
  control:  $BIN_DIR/screenpipe-ctl {start|stop|pause <min>|resume}
  scrub:    python3 $BIN_DIR/scrub-elements.py --dry-run
  config:   $CONFIG
  uninstall: ./uninstall.sh
Turn on FileVault for encryption at rest of $DATA_DIR.
EOF
