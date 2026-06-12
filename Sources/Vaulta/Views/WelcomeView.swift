import SwiftUI
import VaultaCore

/// First-run / no-vault screen: create, open, or pick a recent vault.
struct WelcomeView: View {
    @Environment(AppState.self) private var app
    @State private var showingNewVault = false

    var body: some View {
        HStack(spacing: 0) {
            // Left: brand + primary actions
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    BrandMark(size: 56)
                    Text("Vaulta")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Offline, encrypted secrets for developers.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ActionButton(
                        title: "Create New Vault",
                        subtitle: "Start a fresh AES-256 encrypted vault",
                        systemImage: "plus.circle.fill"
                    ) { showingNewVault = true }

                    ActionButton(
                        title: "Open Vault…",
                        subtitle: "Open an existing .vaulta file",
                        systemImage: "folder.fill"
                    ) {
                        if let url = FilePanels.chooseExistingVault() { app.openVault(at: url) }
                    }
                }

                Spacer()

                Label("\(app.biometricKind.displayName.capitalized) ready · 100% local",
                      systemImage: "checkmark.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(width: 360)

            Divider()

            // Right: recents
            RecentsColumn()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingNewVault) {
            NewVaultSheet()
        }
    }
}

private struct RecentsColumn: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Vaults")
                .font(.headline)
                .padding([.horizontal, .top], 24)
                .padding(.bottom, 12)

            if app.recents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No recent vaults yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(app.recents) { recent in
                        RecentRow(recent: recent)
                            .contentShape(Rectangle())
                            .onTapGesture { app.openRecent(recent) }
                            .contextMenu {
                                Button("Open") { app.openRecent(recent) }
                                Divider()
                                Button("Remove from List") {
                                    app.removeRecent(recent, forgetKey: false)
                                }
                                Button("Remove & Forget Key on This Mac", role: .destructive) {
                                    app.removeRecent(recent, forgetKey: true)
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

private struct RecentRow: View {
    let recent: RecentVault

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.square.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(recent.name).fontWeight(.medium)
                Text(recent.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if !recent.exists {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("File not found")
            }
        }
        .padding(.vertical, 4)
        .opacity(recent.exists ? 1 : 0.5)
    }
}

private struct ActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.semibold)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(hovering ? 0.08 : 0.04))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
