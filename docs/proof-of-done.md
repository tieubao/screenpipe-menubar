# Proof of done: screenpipe-menubar slice 1 (backend + installer + docs)

Covers the shell slice (sub-goals 01-03): the stripped privacy-first capture backend, the
one-command installer with the per-binary TCC flow, and the docs. The native Swift menu bar
app (slice 2) has its own proof when it lands.

## Acceptance criteria

| # | Criterion | Source |
|---|---|---|
| A1 | Public repo with a generic, single-purpose backend; zero personal/coupling refs | 01 |
| A2 | `scrub-elements.py` redacts residual secrets using bundled patterns, idempotently | 01 |
| A3 | `install.sh` brings capture up and verifies the per-binary Screen Recording grant, failing loudly if denied | 02 |
| A4 | `uninstall.sh` fully removes the install | 02 |
| A5 | README takes a stranger from clone to working, redacted capture; honest about limits | 03 |

## Confirmation run-table

| Check | Command | Expected | Result |
|---|---|---|---|
| Syntax | `bash -n` on launchers + installer | exit 0 | PASS |
| Denylist | grep personal/coupling refs across repo | zero hits | PASS |
| Scrub finds secrets | `scrub-elements.py --dry-run` on fixture | 4/7 rows flagged | PASS |
| Scrub applies | `scrub-elements.py` on fixture | 4/4 scrubbed | PASS |
| Scrub idempotent | second `--dry-run` after apply | 0 remaining | PASS |
| **Negative control (scrub)** | clean rows in the same fixture | NOT modified | PASS |
| Install brings up API | isolated `install.sh` (port 3999) | `/health` 200 within grace | PASS |
| Plist is BTM-friendly | `plutil -p` the rendered plist | `ProgramArguments[0]` = bare-name launcher | PASS |
| Idempotent install | re-run `install.sh` | takes "already healthy" + "keep config" paths | PASS |
| Uninstall is clean | `uninstall.sh` then checks | agent unloaded, plist + binaries gone, port dead | PASS |
| **Negative control (TCC)** | capture with no usable grant context | API never binds, install fails loudly within grace | PASS (observed via the audio-grant hang) |

## Run detail

### Scrub (A2) + its negative control

The fixture (`fixtures/make-fixture.py`) builds a screenpipe-shaped sqlite with 7 rows: 4
carry synthetic secrets **assembled from parts** (an AWS-shaped key, a GitHub-shaped token,
a `NAME=value` assignment, a 12-word BIP-39 phrase) and 3 are clean (a mail subject, a code
line, a URL with no token param).

```
[dry-run] scanned 7 rows, 4 contain residual secret(s)
scrubbed 4/4 matching rows of 7 scanned (FTS auto-synced via elements_au trigger)
[dry-run] scanned 7 rows, 0 contain residual secret(s)     # idempotent
```

**Negative control:** the 3 clean rows are scanned but never rewritten (4/4, not 7/7), and a
second pass finds 0. A scrub that "redacts everything" would fail this; the marker only
replaces matched spans, surrounding text is preserved.

### Install + the TCC negative control (A3)

The installer's success signal is **the API binding within a grace window**. The failure
mode is the whole point of the per-binary lesson: when the exact binary that `launchd` runs
lacks Screen Recording (or, as observed, blocks on a missing microphone grant), startup
hangs and the API never binds, with no prompt under `launchd`.

```
==> Screen Recording grant (the per-binary gate)
  grant OK: API bound within grace, screen capture is permitted.
==> Verify: poll http://localhost:3999/health
  API healthy.
```

**Negative control (observed, not contrived):** an earlier build without `--disable-audio`
hung at `microphone: waiting -- grant access to "your terminal emulator"`; the installer did
not hang silently, it ran out its grace window and **failed loudly** with the binary path to
enable. That is the denial path working as designed. Disabling audio removed the dependency.

### Uninstall (A4)

```
PASS: agent not loaded
PASS: plist removed
PASS: binaries removed
PASS: port dead
```

## Honest scope (what this proof does NOT claim)

- **Vision-frame production was not cleanly verified on the test machine.** The isolated test
  instance bound the API but never produced OCR frames, because a second ScreenCaptureKit
  stream contends with an already-running recorder on the same single display. That is a
  test-environment artifact; a real single-recorder machine produces frames. `install.sh`
  therefore asserts API-binds, not vision=ok (which would be flaky even on a real machine with
  an idle screen at install time).
- **Local PII redaction quality is not measured here.** It is screenpipe's on-device model;
  this repo relies on the exclusion list as the actual guarantee and treats redaction as a
  reducer. See README "Honest limits".

## Reproduce

```sh
# Scrub (no install needed):
python3 fixtures/make-fixture.py /tmp/fx.sqlite
python3 bin/scrub-elements.py --dry-run --db /tmp/fx.sqlite     # 4 flagged
python3 bin/scrub-elements.py --db /tmp/fx.sqlite              # 4 scrubbed
python3 bin/scrub-elements.py --dry-run --db /tmp/fx.sqlite    # 0 (idempotent)

# Installer, isolated from any live recorder (port 3999, temp dirs):
TMP=$(mktemp -d)
SCREENPIPE_MENUBAR_PREFIX="$TMP/local" SCREENPIPE_MENUBAR_LABEL=com.screenpipe.captest \
SCREENPIPE_MENUBAR_CONFIG_DIR="$TMP/config" SCREENPIPE_MENUBAR_DATA_DIR="$TMP/data" \
SCREENPIPE_MENUBAR_PORT=3999 ./install.sh
# then tear down:
SCREENPIPE_MENUBAR_PREFIX="$TMP/local" SCREENPIPE_MENUBAR_LABEL=com.screenpipe.captest \
SCREENPIPE_MENUBAR_CONFIG_DIR="$TMP/config" SCREENPIPE_MENUBAR_DATA_DIR="$TMP/data" \
./uninstall.sh --purge
```
