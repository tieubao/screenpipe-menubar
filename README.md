# screenpipe-menubar

A privacy-first, one-command setup for [screenpipe](https://github.com/mediar-ai/screenpipe)
24/7 screen memory on macOS, plus a native menu bar control.

screenpipe records your screen continuously and makes it searchable with OCR. That is
powerful and also a standing liability: keys, seed phrases, and banking screens flow past
the recorder all day. This repo packages a **hardened capture profile** that excludes
password managers, crypto wallets, and banking windows, redacts PII on-device, never
persists typed or copied text, encrypts at rest, and scrubs residual secrets from the local
index. The end state: redacted screen memory you can actually trust, behind one install
command and one permission click.

> Status: early. Slice 1 (shell backend + installer) is landing first; the native Swift menu
> bar app is slice 2.

## Quickstart

```sh
# 1. Install screenpipe itself first (see https://github.com/mediar-ai/screenpipe).
# 2. Then, from a clone of this repo:
./install.sh
```

`install.sh` will:

1. Install the backend to `~/.local/bin` and the secret patterns to `~/.local/share`.
2. Render your config at `~/.config/screenpipe-menubar/config`.
3. **Walk you through the one permission everyone trips on** (see below).
4. Install a `KeepAlive` LaunchAgent and verify the API comes up.

Control it:

```sh
screenpipe-ctl start | stop | pause 60 | resume
python3 ~/.local/bin/scrub-elements.py --dry-run   # check for residual secrets
./uninstall.sh                                     # remove (add --purge to delete data)
```

### The one permission: Screen Recording (per binary)

macOS Screen Recording permission is granted **per binary**, and the prompt does **not**
appear when a process is launched by `launchd`. So a naive "install the LaunchAgent first"
setup hangs silently with no prompt. `install.sh` avoids this: it runs the capture binary in
the **foreground** first, which triggers the normal prompt, and only installs the background
agent once the grant is verified.

If you see a Screen Recording prompt during install, click **Allow**. If install reports the
grant is missing:

1. Open **System Settings > Privacy & Security > Screen Recording**.
2. Enable the screenpipe binary it names (the path is printed in the error).
3. Re-run `./install.sh`.

> Screenshot placeholder: System Settings > Privacy & Security > Screen Recording, with the
> screenpipe binary toggled on.

## Security model

Defense in depth, outermost first. A secret is stopped at the earliest layer that applies:

| Layer | What it does | How |
|---|---|---|
| **1. Exclusion** | password managers, crypto wallets, banking windows are never captured at all | `--ignored-windows` defaults (1Password, Bitwarden, KeePassXC, Ledger Live, Trezor, Electrum, Exodus, MetaMask, Phantom, Rabby, "Recovery Phrase", banking by title); extend in config |
| **2. No transient text** | typed and copied text is never persisted | `--disable-keyboard-capture --disable-clipboard-capture` |
| **3. Local redaction** | PII in OCR/accessibility text + images is redacted on-device, asynchronously | `--use-pii-removal --async-pii-redaction --async-image-pii-redaction --pii-backend local` |
| **4. DRM pause** | protected video is not recorded | `--pause-on-drm-content` |
| **5. Residual scrub** | secrets that slip into the per-element index are overwritten | `scrub-elements.py` (provider regexes + BIP-39 + shape classes, all bundled) |
| **6. At rest** | the on-disk database is encrypted | turn on **FileVault** (screenpipe stores under `~/.screenpipe`) |
| **7. No egress** | nothing leaves the machine | `--disable-telemetry`, local API bound to `127.0.0.1`, no cloud login, no connectors |
| **8. Retention** | old data is pruned | `--retention-days` (default 14) |

## Honest limits

- **Local redaction is not perfect.** On-device PII models have a real miss rate; treat
  redaction as a strong reducer, not a guarantee. The exclusion list (layer 1) is what
  actually keeps wallets and password managers out, because it never captures them in the
  first place. The frontier-quality redaction backends are cloud/subscription paths this
  setup deliberately does not use.
- **The `elements` table needs a scrub.** screenpipe's async redactor reconciles OCR,
  accessibility, and UI-event text but not the per-element `elements` table, so a secret can
  linger there in plaintext until retention prunes it. `scrub-elements.py` is the patch; run
  it periodically (or wire it to a timer). It targets high-stakes secrets (API keys, wallet
  material), not all PII.
- **macOS only.** The installer uses `launchd` and the macOS Screen Recording TCC flow.
- **No audio.** This is a screen-memory tool; audio capture is disabled by default (it also
  avoids a microphone-permission dependency).

## What is in here

```
install.sh / uninstall.sh   one-command setup + clean removal
bin/screenpipe-capture      hardened `screenpipe record` launcher (the privacy profile)
bin/screenpipe-ctl          start | stop | pause <min> | resume (LaunchAgent-aware)
bin/scrub-elements.py       redact residual secrets from the `elements` table
patterns/                   bundled secret-detection patterns (provider regexes + BIP-39)
deploy/                     the LaunchAgent plist template
config.example              tunables: retention, languages, extra excluded windows, port/data-dir
docs/proof-of-done.md       verification + negative-control table
```

## Config reference

Copy `config.example` to `~/.config/screenpipe-menubar/config` (the installer does this) and
edit. Every key:

| Key | Default | Meaning |
|---|---|---|
| `SCREENPIPE_RETENTION_DAYS` | `14` | days of media/text kept before automatic pruning |
| `SCREENPIPE_LANGUAGES` | `english` | OCR languages, space-separated (e.g. `"english vietnamese"`) |
| `SCREENPIPE_EXTRA_IGNORED_WINDOWS` | `""` | extra windows to exclude, beyond the built-in defaults |
| `SCREENPIPE_PATTERNS_DIR` | bundled | override the scrub's secret-pattern directory |
| `SCREENPIPE_PORT` | `3030` | API port (set only to run a second isolated instance) |
| `SCREENPIPE_DATA_DIR` | `~/.screenpipe` | data directory (set only for a second instance) |

## License

MIT. See [LICENSE](LICENSE).
