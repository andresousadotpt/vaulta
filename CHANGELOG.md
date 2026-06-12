# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-12

### Added

- Encrypted vaults using **AES-256-GCM** with a random per-vault 256-bit key.
- **Touch ID / device-password** unlock via a Secure Enclave-backed Keychain item
  (`userPresence`, `WhenUnlockedThisDeviceOnly`).
- Optional **recovery passphrase** wrapping the data key with PBKDF2-HMAC-SHA256
  (600k iterations), implemented on CryptoKit's HMAC — no third-party dependencies.
- **Vaults → Projects → Secrets** model with reveal / copy / edit / delete.
- Onboarding: create, open, and open-recent vaults; resumes the last vault on launch.
- Lock/unlock with auto-lock on idle, sleep, and screen lock.
- **Menu bar** item with quick lock/unlock and recent vaults.
- Export a project to `.env`, direnv `.envrc`, shell `export`, JSON, YAML, and Docker env.
- `VaultaCore` (UI-free, tested) + `Vaulta` (SwiftUI) two-target layout.

[Unreleased]: https://github.com/andresousadotpt/vaulta/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/andresousadotpt/vaulta/releases/tag/v0.1.0
