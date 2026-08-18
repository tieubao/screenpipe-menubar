#!/usr/bin/env bash
# uninstall.sh -- cleanly remove the screenpipe-menubar capture install.
# Removes only the three binaries this installer placed, the LaunchAgent, and boots out the
# agent. Captured DATA and config are kept by default (removing screen memory silently is
# destructive); pass --purge to also delete the data dir, config, and bundled patterns.
#
# Honors the same env overrides as install.sh so a self-test instance can be torn down.
set -uo pipefail

PREFIX="${SCREENPIPE_MENUBAR_PREFIX:-$HOME/.local}"
LABEL="${SCREENPIPE_MENUBAR_LABEL:-com.screenpipe.capture}"
CONFIG_DIR="${SCREENPIPE_MENUBAR_CONFIG_DIR:-$HOME/.config/screenpipe-menubar}"
DATA_DIR="${SCREENPIPE_MENUBAR_DATA_DIR:-$HOME/.screenpipe}"

BIN_DIR="$PREFIX/bin"
SHARE_DIR="$PREFIX/share/screenpipe-menubar"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_="$(id -u)"
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

log() { printf '  %s\n' "$*"; }

printf '==> Boot out the LaunchAgent (%s)\n' "$LABEL"
launchctl bootout "gui/$UID_/$LABEL" 2>/dev/null && log "booted out" || log "agent was not loaded"

printf '==> Remove installed binaries + LaunchAgent plist\n'
for f in "$BIN_DIR/screenpipe-capture" "$BIN_DIR/screenpipe-ctl" "$BIN_DIR/scrub-elements.py" "$PLIST"; do
  if [ -e "$f" ]; then rm -f "$f" && log "removed $f"; fi
done

if [ "$PURGE" -eq 1 ]; then
  printf '==> --purge: remove config, patterns, and captured data\n'
  rm -rf "$SHARE_DIR" "$CONFIG_DIR" "$DATA_DIR" && log "purged $SHARE_DIR, $CONFIG_DIR, $DATA_DIR"
else
  log "kept config ($CONFIG_DIR) and data ($DATA_DIR); pass --purge to delete them"
fi

printf '\nDone. screenpipe-menubar capture uninstalled (label %s).\n' "$LABEL"
