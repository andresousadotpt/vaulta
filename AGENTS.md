# AGENTS.md

Instructions for AI coding agents working on **Vaulta** — a native macOS app for
offline, encrypted developer secrets. Bootstrapped from
[macskeleton](https://github.com/andresousadotpt/macskeleton).

## What this is

- **Product:** A local-only secrets manager. Vaults are AES-256-GCM encrypted files
  unlocked with Touch ID / device password. Hierarchy: **vault → projects → secrets**.
- **Platform:** macOS 14+. Swift Package Manager, no Xcode project file.
- **Dependencies:** none. All crypto uses Apple's CryptoKit; auth uses Security +
  LocalAuthentication. Do not add third-party packages without strong justification.

## Build / test / run

```bash
make build    # debug build (swift build)
make run      # build + swift run
make test     # unit tests — requires full Xcode (uses DEVELOPER_DIR)
make app      # release .app bundle in ./dist/ (ad-hoc signed)
make clean
```

> Keychain + biometric features only behave fully inside a signed `.app` bundle
> (`make app`), not under `swift run`.

## Architecture

Two targets with strict separation:

| Target | Role | May import |
| ------ | ---- | ---------- |
| **VaultaCore** | Models, crypto, keychain, persistence, export. No UI. | Foundation, CryptoKit, Security, LocalAuthentication |
| **Vaulta** | SwiftUI views, menu bar, AppKit bridges, view model | VaultaCore, SwiftUI, AppKit |

```
Sources/
├── VaultaCore/
│   ├── Models/      Secret, Project, VaultContents, VaultFile, RecentVault
│   ├── Services/    CryptoService, KeychainService, BiometricAuth,
│   │                VaultService, RecentVaultsStore, SecretExporter, VaultError
│   └── Utilities/   AtomicFile
└── Vaulta/
    ├── VaultaApp.swift     @main: WindowGroup + MenuBarExtra + Settings
    ├── ViewModels/         AppState (@MainActor @Observable) — the single source of truth
    ├── Views/              RootView, WelcomeView, UnlockView, VaultView, …
    ├── Support/            FilePanels, SystemLockObserver (AppKit bridges)
    └── Resources/          Logo.png (app icon source)
```

### Security model (read before touching crypto)

- Each vault has a random 256-bit **DEK** (Data Encryption Key).
- Vault contents are sealed with **AES-256-GCM** under the DEK (`CryptoService.seal/open`).
- The DEK is stored in the **Keychain** with `SecAccessControlCreateWithFlags(..., .userPresence, ...)`
  and `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (`KeychainService`). It never
  leaves the device and is never serialized into the `.vaulta` file.
- Optional recovery passphrase: DEK wrapped with **PBKDF2-HMAC-SHA256** (600k iters,
  implemented on CryptoKit HMAC in `CryptoService`) and stored in the file header.
- Decrypted state lives only in `AppState.loaded` while `phase == .unlocked`; it is
  dropped on `lock()`, idle timeout, sleep, and screen lock.

**Invariants — do not break:**
- Never write secret material to disk unencrypted (the only file writes go through
  `VaultService.save` / `AtomicFile.write`, always AES-GCM sealed).
- No networking. There is no network code anywhere; keep it that way.
- All file writes are atomic (`AtomicFile`).
- Blocking core work (keychain prompt, PBKDF2, file I/O) runs off the main thread —
  `AppState` wraps it in `Task.detached`.

### UI conventions

- View model: `@MainActor @Observable` (Observation framework, not Combine).
- Pass `AppState` via `.environment(...)`; read with `@Environment(AppState.self)`.
- Use `@Bindable var app = app` when you need bindings into the model.
- AppKit only where SwiftUI can't reach (`FilePanels`, `SystemLockObserver`).
- Sheets must not live inside `Menu` content — present them from the parent view.

## Where to add things

- New model / field → `Sources/VaultaCore/Models/` (keep `Codable`, `Sendable`, `Equatable`).
- New crypto / storage logic → `Sources/VaultaCore/Services/`.
- New export format → `SecretExporter.Format` + a case in `export(_:as:)` + a test.
- New screen → `Sources/Vaulta/Views/`, routed from `RootView` or pushed as a sheet.
- New AppKit bridge → `Sources/Vaulta/Support/`.

## Testing

Tests live in `Tests/VaultaCoreTests/` and target **VaultaCore only** (UI/AppKit are
not unit-tested). Keychain/biometric paths can't be unit-tested (they require a signed
app + user interaction) — test the crypto, model, and export logic instead. Use low
PBKDF2 iteration counts in tests for speed.

```bash
make test
swift test --filter VaultaCoreTests.CryptoServiceTests
```

## Packaging / release

App identity lives in `packaging/app.env` (sourced by `Makefile`, build scripts, CI).
Version source of truth is `packaging/Info.plist` (`CFBundleShortVersionString`).
The icon is `Sources/Vaulta/Resources/Logo.png`; `packaging/generate-icon.swift`
regenerates it (compile with `swiftc` first if the script interpreter can't link AppKit).
Releases are ad-hoc signed — no Apple Developer ID required.

## Git / PR

- Do not commit or push unless explicitly asked.
- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`.
- Don't commit `.build/`, `dist/`, `.DS_Store`, or any `.vaulta` files / secrets.
- Before finishing: `make build`, and `make test` when core logic changed.
