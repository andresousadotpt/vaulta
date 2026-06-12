import SwiftUI
import VaultaCore

/// The lock screen for a selected-but-locked vault. Offers biometric unlock and,
/// if the vault has one, a recovery-passphrase fallback.
struct UnlockView: View {
    @Environment(AppState.self) private var app
    let recent: RecentVault

    @State private var showPassphrase = false
    @State private var passphrase = ""
    @State private var rememberOnDevice = true
    @State private var hasRecoveryPassphrase = false
    @FocusState private var passphraseFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                BrandMark(size: 64)

                VStack(spacing: 4) {
                    Text(recent.name)
                        .font(.title).bold()
                    Text("This vault is locked")
                        .foregroundStyle(.secondary)
                }

                if showPassphrase {
                    passphraseEntry
                } else {
                    biometricEntry
                }
            }
            .frame(width: 340)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            )

            Spacer()

            Button("Switch Vault") { app.goToWelcome() }
                .buttonStyle(.link)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
        .onAppear { hasRecoveryPassphrase = checkRecovery() }
    }

    private var biometricEntry: some View {
        VStack(spacing: 12) {
            Button {
                app.unlockWithBiometrics()
            } label: {
                Label("Unlock with \(app.biometricKind.displayName.capitalized)",
                      systemImage: app.biometricKind == .none ? "key.fill" : "touchid")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(app.isBusy)

            if hasRecoveryPassphrase {
                Button("Use recovery passphrase") {
                    withAnimation { showPassphrase = true }
                }
                .buttonStyle(.link)
            }

            if app.isBusy {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var passphraseEntry: some View {
        VStack(spacing: 12) {
            SecureField("Recovery passphrase", text: $passphrase)
                .textFieldStyle(.roundedBorder)
                .focused($passphraseFocused)
                .onSubmit(submitPassphrase)

            Toggle("Remember on this Mac (enable Touch ID)", isOn: $rememberOnDevice)
                .font(.caption)
                .toggleStyle(.checkbox)

            Button("Unlock", action: submitPassphrase)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(passphrase.isEmpty || app.isBusy)

            Button("Back") { withAnimation { showPassphrase = false } }
                .buttonStyle(.link)
        }
        // Make the field first responder once the entry is on screen, so the
        // user can type immediately instead of having to click into it first.
        .onAppear { DispatchQueue.main.async { passphraseFocused = true } }
    }

    private func submitPassphrase() {
        guard !passphrase.isEmpty else { return }
        app.unlockWithPassphrase(passphrase, rememberOnDevice: rememberOnDevice)
        passphrase = ""
    }

    private func checkRecovery() -> Bool {
        (try? VaultService.readHeader(at: recent.url))?.hasRecoveryPassphrase ?? false
    }
}
