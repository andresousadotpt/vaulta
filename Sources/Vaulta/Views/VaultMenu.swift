import SwiftUI
import AppKit
import VaultaCore

/// Shared vault-level actions used in the toolbar overflow menu. The presenting
/// view owns the rename / passphrase sheets (sheets can't live in Menu content).
struct VaultMenu: View {
    @Environment(AppState.self) private var app
    let onRenameVault: () -> Void
    let onSetPassphrase: () -> Void

    var body: some View {
        Button("Rename Vault…", action: onRenameVault)
        if let loaded = app.loaded {
            Button(loaded.hasRecoveryPassphrase ? "Change Recovery Passphrase…" : "Add Recovery Passphrase…",
                   action: onSetPassphrase)
        }
        Divider()
        if let url = app.loaded?.url {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        Button("Lock Vault") { app.lock() }
        Button("Close Vault") { app.goToWelcome() }
    }
}
