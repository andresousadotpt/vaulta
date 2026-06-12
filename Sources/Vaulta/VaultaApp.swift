import SwiftUI
import AppKit
import VaultaCore

/// Forces the process to be a regular, foreground GUI app at launch.
///
/// When run as a bare SwiftPM binary (`swift run`, i.e. not inside a `.app`
/// bundle), macOS does not promote the process to a foreground application, so
/// it never becomes active and keystrokes keep going to the launching terminal
/// instead of our windows. Setting `.regular` and activating fixes that. For
/// the packaged `.app` this is already the case, so it's a harmless no-op.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct VaultaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var app = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(app)
                .frame(minWidth: 820, minHeight: 540)
                .onAppear { app.bootstrap() }
                .background(SystemLockObserver { app.handleSystemLockOrSleep() })
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                if app.isUnlocked {
                    Button("Lock Vault") { app.lock() }
                        .keyboardShortcut("l", modifiers: [.command, .shift])
                }
            }
        }

        MenuBarExtra("Vaulta", systemImage: app.isUnlocked ? "lock.open.fill" : "lock.fill") {
            MenuBarContent(openMainWindow: { openWindow(id: "main") })
                .environment(app)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(app)
        }
    }
}
