# screenpipe-menubar

A privacy-first, one-command setup for [screenpipe](https://github.com/mediar-ai/screenpipe)
24/7 screen memory on macOS, plus a native menu bar control.

screenpipe captures your screen continuously and makes it searchable with OCR. That is
powerful and also a standing liability: keys, seed phrases, and banking screens flow past
the recorder all day. This repo packages a **hardened capture profile** that excludes
password managers / crypto wallets / banking windows, redacts PII on-device, never persists
typed or copied text, encrypts at rest, and ships a small tool to scrub residual secrets
from the local index. The end state: redacted screen memory you can actually trust, behind
one install command and one permission grant.

> Status: early. Slice 1 (shell backend + installer) is landing first; the native Swift
> menu bar app is slice 2. The roadmap lives in the author's ops monorepo.

## What is in here

```
bin/screenpipe-capture   hardened `screenpipe record` launcher (the privacy profile)
bin/screenpipe-ctl       start | stop | pause <min> | resume (LaunchAgent-aware)
bin/scrub-elements.py    redact residual secrets from screenpipe's `elements` table
patterns/                bundled secret-detection patterns (provider regexes + BIP-39)
config.example           tunables: retention, languages, extra excluded windows
```

## The privacy profile

`bin/screenpipe-capture` runs `screenpipe record` with:

- **App/window exclusions** for 1Password, Bitwarden, KeePassXC, Ledger Live, Trezor Suite,
  Electrum, Exodus, MetaMask, Phantom, Rabby, "Recovery Phrase", and banking windows by
  title. Extend via `SCREENPIPE_EXTRA_IGNORED_WINDOWS` in your config.
- **On-device PII redaction** (`--use-pii-removal --pii-backend local`), async so it never
  blocks capture, covering secrets, people, emails, phones, addresses, IDs, SSNs, cards, IBANs.
- **No typed/clipboard persistence** (`--disable-keyboard-capture --disable-clipboard-capture`).
- **DRM-aware pause** (`--pause-on-drm-content`) so protected video is not recorded.
- **Encryption at rest** via FileVault (turn it on; screenpipe stores under `~/.screenpipe`).
- **No telemetry** (`--disable-telemetry`).
- **A quiet performance profile** (input-latency priority, capture debounce, low video
  quality) so 24/7 capture stays cheap.

## scrub-elements.py

screenpipe's async redactor reconciles OCR / accessibility / UI-event text but not the
per-element `elements` table, so a secret can linger there in plaintext. This tool finds and
overwrites those residuals using the bundled `patterns/` set. It prints counts only, never
the matched value, and is idempotent.

```sh
python3 bin/scrub-elements.py --dry-run   # report counts, no writes
python3 bin/scrub-elements.py             # redact in place
```

## Install

The one-command installer arrives in the next slice. Until then, see `config.example` and
the scripts in `bin/`.

## License

MIT. See [LICENSE](LICENSE).
