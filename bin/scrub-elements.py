#!/usr/bin/env python3
"""Scrub residual SECRETS from screenpipe's `elements` table.

screenpipe's async redaction worker reconciles ocr_text / accessibility_text /
ui_events but NOT the per-element `elements` table (an upstream gap). So a key /
seed / wallet string that was redacted everywhere on the cloud surface can still
sit in plaintext in `elements.text` for up to the retention window. The cloud ETL
never reads `elements`, so this is not a cloud-leak path; this scrub is
defense-in-depth for the on-disk plaintext of high-stakes SECRETS specifically
(API keys, crypto wallet material), not a full PII redactor.

Pattern set (all bundled in-repo under patterns/, no external dependency):
  - provider regexes (AWS / GitHub / Anthropic / OpenAI / Stripe / 1Password / PEM /
    hex / Bitcoin WIF / xprv / secret-like assignment) from patterns/secrets.json
  - a BIP-39 seed-phrase detector over patterns/bip39-english.txt
  - three shape-class regexes the provider set misses: an ssh public/key body, a
    NAME=value secret assignment, and a URL-embedded token.
Override the pattern dir with SCREENPIPE_PATTERNS_DIR; default = <repo>/patterns.

Matched spans are overwritten with a marker; surrounding text is preserved. The
`elements_au` FTS trigger keeps `elements_fts` in sync on UPDATE automatically.

Metrics only: never prints a matched secret value. Idempotent: a second run finds
nothing new. Usage:
  scrub-elements.py --dry-run     report what WOULD be redacted (counts), no writes
  scrub-elements.py               redact in place
  scrub-elements.py --db PATH     target a specific sqlite db
"""
import argparse
import json
import os
import re
import sqlite3
import sys

DB = os.path.expanduser("~/.screenpipe/db.sqlite")
# Default to the patterns bundled next to this script's repo, not any user-global path.
_REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATTERNS_DIR = os.environ.get("SCREENPIPE_PATTERNS_DIR", os.path.join(_REPO, "patterns"))
SG_JSON = os.path.join(PATTERNS_DIR, "secrets.json")
BIP39 = os.path.join(PATTERNS_DIR, "bip39-english.txt")
MARKER = "[REDACTED-SECRET]"

# shape-class regexes the provider-shaped secrets.json misses
SHAPE = [
    ("ssh_key_body", re.compile(r"\bAAAA[A-Za-z0-9+/]{16,}={0,2}")),
    ("env_assignment", re.compile(
        r"\b[A-Z][A-Z0-9_]*(?:KEY|TOKEN|SECRET|PASSWORD|PASSPHRASE|CREDENTIAL)S?\b\s*=\s*"
        r"[\"']?[A-Za-z0-9+/=_.~!@#$%^&*-]{8,}[\"']?")),
    ("url_token", re.compile(
        r"https?://[^\s|\"]*[?&](?:token|key|secret|api_?key|access_?token|auth|sig(?:nature)?)="
        r"[A-Za-z0-9._~-]{8,}[^\s|\"]*")),
]
WORD_RE = re.compile(r"[a-z]+")


def load_patterns():
    pats = []
    try:
        with open(SG_JSON) as f:
            for p in json.load(f):
                pats.append((p["n"], re.compile(p["r"])))
    except OSError:
        print(f"WARNING: {SG_JSON} not found; provider patterns skipped", file=sys.stderr)
    pats.extend(SHAPE)
    try:
        with open(BIP39) as f:
            wl = {w.strip() for w in f if w.strip()}
    except OSError:
        wl = set()
    return pats, wl


def bip39_spans(text, wl):
    if not wl:
        return []
    words = [(m.start(), m.end(), m.group(0)) for m in WORD_RE.finditer(text.lower())]
    out, run = [], []
    for s, e, w in words + [(None, None, None)]:
        if w is not None and w in wl and (not run or s - run[-1][1] <= 1):
            run.append((s, e))
            continue
        if len(run) >= 12:
            out.append((run[0][0], run[-1][1]))
        run = [(s, e)] if (w is not None and w in wl) else []
    return out


def find_spans(text, pats, wl):
    spans = []
    for _name, rx in pats:
        for m in rx.finditer(text):
            spans.append((m.start(), m.end()))
    spans.extend(bip39_spans(text, wl))
    if not spans:
        return []
    # merge overlaps, left to right
    spans.sort()
    merged = [spans[0]]
    for s, e in spans[1:]:
        if s <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], e))
        else:
            merged.append((s, e))
    return merged


def redact(text, spans):
    out, prev = [], 0
    for s, e in spans:
        out.append(text[prev:s])
        out.append(MARKER)
        prev = e
    out.append(text[prev:])
    return "".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--db", default=DB)
    args = ap.parse_args()

    pats, wl = load_patterns()
    con = sqlite3.connect(args.db, timeout=5.0)
    con.execute("PRAGMA busy_timeout=5000")
    cur = con.cursor()

    scanned = matched = 0
    updates = []
    for rid, text in cur.execute(
            "SELECT id, text FROM elements WHERE text IS NOT NULL AND length(text) > 7"):
        scanned += 1
        if MARKER in text:
            continue  # already scrubbed
        spans = find_spans(text, pats, wl)
        if not spans:
            continue
        matched += 1
        updates.append((redact(text, spans), rid))

    if args.dry_run:
        print(f"[dry-run] scanned {scanned} rows, {matched} contain residual secret(s) "
              f"(no writes)")
        con.close()
        return

    n = 0
    for newtext, rid in updates:
        try:
            cur.execute("UPDATE elements SET text=? WHERE id=?", (newtext, rid))
            n += 1
        except sqlite3.OperationalError as e:
            print(f"WARNING: row {rid} skipped ({e})", file=sys.stderr)
    con.commit()
    con.close()
    print(f"scrubbed {n}/{matched} matching rows of {scanned} scanned "
          f"(FTS auto-synced via elements_au trigger)")


if __name__ == "__main__":
    main()
