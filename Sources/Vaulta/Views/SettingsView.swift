import SwiftUI
import VaultaCore

struct SettingsView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView {
            Form {
                Section("Security") {
                    Picker("Auto-lock after", selection: $app.autoLockMinutes) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("Never").tag(0)
                    }
                    LabeledContent("Biometrics", value: app.biometricKind.displayName.capitalized)
                    Text("Vaults also lock automatically when your Mac sleeps or the screen locks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Section("About Vaulta") {
                    LabeledContent("Version", value: AppVersion.marketing)
                    LabeledContent("Encryption", value: "AES-256-GCM")
                    LabeledContent("Key derivation", value: "PBKDF2-HMAC-SHA256")
                    LabeledContent("Data", value: "100% local, this device only")
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 280)
    }
}
