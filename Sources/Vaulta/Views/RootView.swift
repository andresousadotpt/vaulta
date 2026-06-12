import SwiftUI
import VaultaCore

/// Routes between the three top-level phases: welcome, locked, unlocked.
struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Group {
            switch app.phase {
            case .welcome:
                WelcomeView()
            case .locked(let recent):
                UnlockView(recent: recent)
            case .unlocked:
                VaultView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: app.phase)
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { app.errorMessage != nil },
                set: { if !$0 { app.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { app.errorMessage = nil }
        } message: {
            Text(app.errorMessage ?? "")
        }
    }
}
