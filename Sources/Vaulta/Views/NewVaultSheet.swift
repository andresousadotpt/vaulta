import SwiftUI
import VaultaCore

/// Collects a name, optional recovery passphrase, then asks where to save.
struct NewVaultSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var addPassphrase = false
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""

    private var passphraseValid: Bool {
        !addPassphrase || (!passphrase.isEmpty && passphrase == confirmPassphrase)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                BrandMark(size: 36)
                Text("New Vault").font(.title2).bold()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Vault name").font(.subheadline).foregroundStyle(.secondary)
                TextField("e.g. Personal, Work, Side Projects", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle(isOn: $addPassphrase) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a recovery passphrase")
                    Text("Lets you recover this vault if the device key is ever lost, or open it on another Mac. Day-to-day you'll still unlock with \(app.biometricKind.displayName).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if addPassphrase {
                VStack(spacing: 8) {
                    SecureField("Recovery passphrase", text: $passphrase)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Confirm passphrase", text: $confirmPassphrase)
                        .textFieldStyle(.roundedBorder)
                    if !passphrase.isEmpty && passphrase != confirmPassphrase {
                        Label("Passphrases don't match", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Label("Encrypted with AES-256-GCM. Nothing leaves this Mac.",
                  systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Choose Location & Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || !passphraseValid)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func create() {
        guard let url = FilePanels.chooseNewVaultFile(defaultName: name) else { return }
        app.createVault(
            name: name,
            at: url,
            passphrase: addPassphrase ? passphrase : nil
        )
        dismiss()
    }
}
