import SwiftUI
import AppKit

/// Invokes `onLock` when the screen locks or the Mac goes to sleep, so Vaulta
/// can drop decrypted secrets from memory automatically.
struct SystemLockObserver: View {
    let onLock: () -> Void
    @State private var coordinator = Coordinator()

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { coordinator.start(onLock: onLock) }
            .onDisappear { coordinator.stop() }
    }

    @MainActor
    final class Coordinator {
        private var tokens: [NSObjectProtocol] = []
        private var onLock: (() -> Void)?

        func start(onLock: @escaping () -> Void) {
            guard tokens.isEmpty else { return }
            self.onLock = onLock
            // The observer block must be @Sendable; capture only `self` (a
            // @MainActor class, hence Sendable) and hop back to the main actor.
            let handler: @Sendable (Notification) -> Void = { [weak self] _ in
                Task { @MainActor in self?.onLock?() }
            }

            let ws = NSWorkspace.shared.notificationCenter
            tokens.append(ws.addObserver(forName: NSWorkspace.willSleepNotification,
                                         object: nil, queue: .main, using: handler))
            tokens.append(ws.addObserver(forName: NSWorkspace.screensDidSleepNotification,
                                         object: nil, queue: .main, using: handler))

            let dnc = DistributedNotificationCenter.default()
            tokens.append(dnc.addObserver(forName: .init("com.apple.screenIsLocked"),
                                          object: nil, queue: .main, using: handler))
        }

        func stop() {
            let ws = NSWorkspace.shared.notificationCenter
            let dnc = DistributedNotificationCenter.default()
            for token in tokens {
                ws.removeObserver(token)
                dnc.removeObserver(token)
            }
            tokens.removeAll()
        }
    }
}
