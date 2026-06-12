import SwiftUI
import AppKit
import VaultaCore

/// One secret paired with the project it lives in — a flat search hit across the
/// whole unlocked vault.
fileprivate struct SecretHit: Identifiable {
    let project: Project
    let secret: Secret
    var id: UUID { secret.id }
}

/// The menu-bar panel (window style). When the vault is unlocked it offers a
/// search field over every secret in the vault; clicking a result copies its
/// value straight to the clipboard. When locked it offers a quick unlock; when
/// no vault is open it lists recents.
struct MenuBarContent: View {
    @Environment(AppState.self) private var app
    let openMainWindow: () -> Void

    @State private var search = ""
    @State private var copiedSecretId: UUID?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            switch app.phase {
            case .unlocked:
                unlockedSection
            case .locked(let recent):
                lockedSection(recent)
            case .welcome:
                welcomeSection
            }

            Divider()
            footer
        }
        .frame(width: 340)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            BrandMark(size: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text("Vaulta").font(.headline)
                Text(statusText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
    }

    private var statusText: String {
        switch app.phase {
        case .unlocked: return "\(app.currentVaultName) — unlocked"
        case .locked(let r): return "\(r.name) — locked"
        case .welcome: return "No vault open"
        }
    }

    // MARK: - Unlocked: search + copy

    private var unlockedSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search secrets", text: $search)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { if let first = hits.first { copy(first) } }
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            Divider()

            if hits.isEmpty {
                Text(app.projects.allSatisfy { $0.secrets.isEmpty }
                     ? "This vault has no secrets yet."
                     : "No secrets match “\(search)”.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(hits) { hit in
                            SecretHitRow(
                                hit: hit,
                                copied: copiedSecretId == hit.secret.id,
                                onCopy: { copy(hit) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .onAppear { DispatchQueue.main.async { searchFocused = true } }
    }

    /// Every secret in the vault, sorted by key, filtered by the search text.
    private var hits: [SecretHit] {
        let all = app.projects.flatMap { project in
            project.secrets.map { SecretHit(project: project, secret: $0) }
        }
        let sorted = all.sorted {
            $0.secret.key.localizedCaseInsensitiveCompare($1.secret.key) == .orderedAscending
        }
        guard !search.isEmpty else { return sorted }
        return sorted.filter {
            $0.secret.key.localizedCaseInsensitiveContains(search) ||
            $0.project.name.localizedCaseInsensitiveContains(search) ||
            $0.secret.note.localizedCaseInsensitiveContains(search)
        }
    }

    private func copy(_ hit: SecretHit) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(hit.secret.value, forType: .string)
        app.noteActivity()
        copiedSecretId = hit.secret.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedSecretId == hit.secret.id { copiedSecretId = nil }
        }
    }

    // MARK: - Locked: quick unlock

    private func lockedSection(_ recent: RecentVault) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("“\(recent.name)” is locked")
                .font(.callout)
            Button {
                NSApp.activate(ignoringOtherApps: true)
                app.unlockWithBiometrics()
            } label: {
                Label("Unlock with \(app.biometricKind.displayName.capitalized)",
                      systemImage: app.biometricKind == .none ? "key.fill" : "touchid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(app.isBusy)

            if app.isBusy { ProgressView().controlSize(.small) }

            Button("Open Window to unlock…") { openAndActivate() }
                .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
    }

    // MARK: - Welcome: recents

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if app.recents.isEmpty {
                Text("No vaults yet. Open the window to create one.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                Text("Open Recent").font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.top, 8)
                ForEach(app.recents) { recent in
                    Button {
                        openAndActivate { app.openRecent(recent) }
                    } label: {
                        Label(recent.name, systemImage: "lock.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!recent.exists)
                }
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 14) {
            Button { openAndActivate() } label: { Label("Open Window", systemImage: "macwindow") }
            Spacer()
            if app.isUnlocked {
                Button { app.lock() } label: { Label("Lock", systemImage: "lock.fill") }
            }
            Button { NSApp.terminate(nil) } label: { Label("Quit", systemImage: "power") }
                .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .padding(10)
    }

    /// Open the main window, then bring the app forward and make the window key.
    ///
    /// Order matters: the window must exist before we activate, otherwise the
    /// freshly created window never becomes key and text fields (e.g. the
    /// passphrase entry) silently refuse keystrokes. Activating on the next
    /// runloop tick gives SwiftUI time to create and order the window in.
    private func openAndActivate(_ then: (() -> Void)? = nil) {
        openMainWindow()
        then?()
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows
                .first { $0.canBecomeKey && !($0 is NSPanel) }?
                .makeKeyAndOrderFront(nil)
        }
    }
}

/// A single search-result row: key + project, with a hover highlight and a
/// transient "Copied" confirmation. Click anywhere to copy the value.
fileprivate struct SecretHitRow: View {
    let hit: SecretHit
    let copied: Bool
    let onCopy: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.secret.key)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                    Text(hit.project.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if copied {
                    Label("Copied", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.secondary)
                        .opacity(hovering ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(hovering ? Color.primary.opacity(0.08) : .clear)
        .onHover { hovering = $0 }
        .help("Copy \(hit.secret.key) to clipboard")
    }
}
