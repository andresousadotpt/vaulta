import SwiftUI
import VaultaCore

/// Set or change the recovery passphrase on the open vault.
struct RecoveryPassphraseSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var passphrase = ""
    @State private var confirm = ""
    @FocusState private var passphraseFocused: Bool

    private var valid: Bool { !passphrase.isEmpty && passphrase == confirm }
    private var hasExisting: Bool { app.loaded?.hasRecoveryPassphrase ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(hasExisting ? "Change Recovery Passphrase" : "Add Recovery Passphrase")
                .font(.title2).bold()

            Text("A recovery passphrase lets you open this vault if the device key is lost (e.g. after reinstalling macOS) or on another Mac. It's used to wrap the vault's encryption key with PBKDF2-HMAC-SHA256.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("New passphrase", text: $passphrase)
                .textFieldStyle(.roundedBorder)
                .focused($passphraseFocused)
            SecureField("Confirm passphrase", text: $confirm)
                .textFieldStyle(.roundedBorder)

            if !passphrase.isEmpty && passphrase != confirm {
                Label("Passphrases don't match", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    app.setRecoveryPassphrase(passphrase)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!valid)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { DispatchQueue.main.async { passphraseFocused = true } }
    }
}
