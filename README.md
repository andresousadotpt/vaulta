<div align="center">
  <img src="Sources/Vaulta/Resources/Logo.png" width="120" alt="Vaulta icon">
  <h1>Vaulta</h1>
  <p><strong>Offline, encrypted secrets for developers.</strong></p>
</div>

Vaulta is a native macOS app for storing key/value secrets in **AES-256-GCM encrypted** vaults, unlocked with **Touch ID or your Mac's password**. Everything is **100% local** — there is no account, no sync, no telemetry, and no network code. Your secrets never leave your Mac.

Organize secrets into **vaults → projects → secrets**, and export any project to developer-friendly formats: `.env`, direnv `.envrc`, shell `export`, JSON, YAML, and Docker env files.

## Features

- 🔐 **AES-256-GCM** authenticated encryption for every vault.
- 👆 **Touch ID / device password** unlock via the Secure Enclave-backed Keychain.
- 📴 **100% offline** — no networking, no accounts, no analytics.
- 🗂 **Vaults → Projects → Secrets** hierarchy.
- 🧰 **Export** to `.env`, `.envrc` (direnv), shell, JSON, YAML, Docker env.
- 🪟 **Menu bar + window** — quick lock/unlock and recent vaults from the menu bar.
- 🔁 **Resume last vault** on launch; **auto-lock** on idle, sleep, or screen lock.
- 🔑 **Optional recovery passphrase** (PBKDF2-HMAC-SHA256) for portability/recovery.

## How the security works

| Layer | Mechanism |
| ----- | --------- |
| Vault contents | Encrypted with a random 256-bit **Data Encryption Key (DEK)** using **AES-256-GCM**. |
| DEK at rest | Stored in the macOS **Keychain** behind a `userPresence` access control (**Touch ID or device password**), flagged `WhenUnlockedThisDeviceOnly` — never synced, never backed up off-device. |
| Recovery (optional) | The DEK is *also* wrapped with a passphrase-derived key (**PBKDF2-HMAC-SHA256, 600k iterations**) and stored in the vault file, so you can recover or open the vault on another Mac. |
| In memory | Decrypted secrets exist only while the vault is unlocked and are dropped on lock, idle timeout, sleep, or screen lock. |

The `.vaulta` file on disk contains only ciphertext and non-secret metadata. **Nothing is recoverable from it without the key** — which only leaves your Mac if you set a recovery passphrase and choose to move the file.

## Vault file format (`.vaulta`)

A JSON envelope with no plaintext secrets:

```jsonc
{
  "magic": "VAULTA",
  "formatVersion": 1,
  "vaultId": "…",
  "name": "Personal",
  "kdf": { "algorithm": "PBKDF2-HMAC-SHA256", "salt": "…", "iterations": 600000 }, // only if a passphrase is set
  "wrappedKey": "…",   // DEK sealed by the passphrase-derived key (optional)
  "payload": "…"        // vault contents sealed by the DEK (AES-256-GCM combined box)
}
```

## Install

### Build from source (recommended — no Gatekeeper warnings)

```bash
git clone https://github.com/andresousadotpt/vaulta.git
cd vaulta
make app
open dist/vaulta.app
```

Requirements: macOS 14 (Sonoma) or later. Full Xcode is required for `make test`; Command Line Tools suffice for `make build` / `make app`.

### Homebrew

```bash
brew tap andresousadotpt/tap
brew install --cask vaulta
```

If macOS blocks the first launch, right-click the app → **Open**, or use System Settings → Privacy & Security → **Open Anyway**.

## Usage

1. **Create a vault** — choose a name, optionally set a recovery passphrase, and pick where to save the `.vaulta` file.
2. **Add projects** in the sidebar (e.g. `web-api`, `staging`).
3. **Add secrets** (key/value, with an optional note). Reveal, copy, edit, or delete from the row.
4. **Export** a project from the toolbar to `.env`, direnv, JSON, and more.
5. **Lock** any time with ⇧⌘L, the toolbar, or the menu bar. Vaulta reopens your last vault on next launch.

## Development

```bash
make build    # debug build
make run      # build and launch via swift run
make test     # unit tests (requires full Xcode)
make app      # release .app in ./dist/
make clean    # remove build artifacts
```

### Architecture

| Target | Role | Depends on |
| ------ | ---- | ---------- |
| **VaultaCore** | Models, crypto, keychain, persistence, export — no SwiftUI/AppKit | Foundation, CryptoKit, Security, LocalAuthentication |
| **Vaulta** | SwiftUI views, menu bar, AppKit bridges | VaultaCore |

All cryptography is built on Apple's **CryptoKit** (AES-GCM, HMAC); PBKDF2 is implemented on CryptoKit's HMAC so there are **zero third-party dependencies**.

## Releasing

Version lives in `packaging/Info.plist` (`CFBundleShortVersionString`). Push to `main` and GitHub Actions auto-bumps the patch, builds an ad-hoc signed `.app`, publishes a Release zip, and updates the Homebrew cask. For minor/major: `make bump-version BUMP=minor`, commit, then merge.

## Documents

| Document | Purpose |
| -------- | ------- |
| [AGENTS.md](AGENTS.md) | Architecture and conventions for contributors / AI agents |
| [SECURITY.md](SECURITY.md) | Threat model and how to report vulnerabilities |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

## License

MIT — see [LICENSE](LICENSE).
