import SwiftUI
import AppKit
import VaultaCore

/// The single source of truth for the app's runtime state and the bridge to
/// `VaultaCore`. All secret material is held only while `phase == .unlocked`.
@MainActor
@Observable
final class AppState {

    enum Phase: Equatable {
        case welcome
        case locked(RecentVault)
        case unlocked
    }

    // MARK: - Observable state

    private(set) var phase: Phase = .welcome
    private(set) var loaded: LoadedVault?
    private(set) var recents: [RecentVault] = []
    private(set) var biometricKind: BiometricAuth.Kind = .none

    var selectedProjectId: UUID?
    var errorMessage: String?
    var isBusy = false

    // Auto-lock
    var autoLockMinutes: Int {
        didSet { UserDefaults.standard.set(autoLockMinutes, forKey: "vaulta.autoLockMinutes") }
    }
    private var lastActivity = Date()
    private var lockTimer: Timer?

    private let recentsStore = RecentVaultsStore.shared

    init() {
        let stored = UserDefaults.standard.integer(forKey: "vaulta.autoLockMinutes")
        self.autoLockMinutes = stored == 0 ? 10 : stored
        self.recents = recentsStore.all()
        self.biometricKind = BiometricAuth.availableKind()
    }

    // MARK: - Launch routing

    /// Decide the initial screen: resume the last vault (locked) or show welcome.
    func bootstrap() {
        recents = recentsStore.all()
        if let last = recentsStore.lastActiveVault(), last.exists {
            phase = .locked(last)
        } else {
            phase = .welcome
        }
        startLockTimer()
    }

    var currentVaultName: String {
        switch phase {
        case .unlocked: return loaded?.contents.name ?? "Vault"
        case .locked(let r): return r.name
        case .welcome: return "Vaulta"
        }
    }

    var isUnlocked: Bool { if case .unlocked = phase { return true } else { return false } }

    // MARK: - Create / Open

    func createVault(name: String, at url: URL, passphrase: String?) {
        run { [self] in
            let vault = try await detached { try VaultService.createVault(name: name, at: url, passphrase: passphrase) }
            await MainActor.run {
                self.setUnlocked(vault)
            }
        }
    }

    /// Open a vault file the user picked. Routes to the lock screen; if a key is
    /// stored on this Mac, immediately attempts a biometric unlock.
    func openVault(at url: URL) {
        run { [self] in
            let header = try await detached { try VaultService.readHeader(at: url) }
            let recent = RecentVault(
                vaultId: header.vaultId,
                name: header.name,
                path: url.path,
                lastOpened: Date()
            )
            await MainActor.run {
                self.phase = .locked(recent)
            }
            if VaultService.hasStoredKey(for: header.vaultId) {
                await MainActor.run { self.unlockWithBiometrics() }
            }
        }
    }

    func openRecent(_ recent: RecentVault) {
        guard recent.exists else {
            errorMessage = "That vault file could not be found at \(recent.path)."
            recentsStore.remove(vaultId: recent.vaultId)
            recents = recentsStore.all()
            return
        }
        openVault(at: recent.url)
    }

    // MARK: - Unlock

    func unlockWithBiometrics() {
        guard case .locked(let recent) = phase else { return }
        let reason = "Unlock the \"\(recent.name)\" vault"
        run { [self] in
            do {
                let vault = try await detached {
                    try VaultService.unlockWithBiometrics(at: recent.url, reason: reason)
                }
                await MainActor.run { self.setUnlocked(vault) }
            } catch let error as VaultError {
                // Cancelation is not an error worth shouting about.
                if error != .authenticationCanceled {
                    await MainActor.run { self.errorMessage = error.errorDescription }
                }
            }
        }
    }

    func unlockWithPassphrase(_ passphrase: String, rememberOnDevice: Bool) {
        guard case .locked(let recent) = phase else { return }
        run { [self] in
            let vault = try await detached {
                try VaultService.unlockWithPassphrase(
                    at: recent.url, passphrase: passphrase, storeInKeychain: rememberOnDevice
                )
            }
            await MainActor.run { self.setUnlocked(vault) }
        }
    }

    // MARK: - Lock

    func lock() {
        guard let loaded else { return }
        let recent = RecentVault(
            vaultId: loaded.vaultId,
            name: loaded.contents.name,
            path: loaded.url.path,
            lastOpened: Date()
        )
        self.loaded = nil
        self.selectedProjectId = nil
        self.phase = .locked(recent)
    }

    func goToWelcome() {
        loaded = nil
        selectedProjectId = nil
        recents = recentsStore.all()
        phase = .welcome
    }

    // MARK: - Mutations (persisted)

    func addProject(name: String) {
        mutate { try $0.addProject(name: name) }
    }

    func renameProject(id: UUID, to name: String) {
        mutate { try $0.renameProject(id: id, to: name) }
    }

    func deleteProject(id: UUID) {
        mutate { $0.deleteProject(id: id) }
        if selectedProjectId == id { selectedProjectId = nil }
    }

    func addSecret(toProject projectId: UUID, key: String, value: String, note: String) {
        mutate { try $0.addSecret(toProject: projectId, key: key, value: value, note: note) }
    }

    func updateSecret(inProject projectId: UUID, secretId: UUID, key: String, value: String, note: String) {
        mutate { try $0.updateSecret(inProject: projectId, secretId: secretId, key: key, value: value, note: note) }
    }

    func deleteSecret(inProject projectId: UUID, secretId: UUID) {
        mutate { $0.deleteSecret(inProject: projectId, secretId: secretId) }
    }

    func renameVault(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate { $0.name = trimmed }
    }

    func setRecoveryPassphrase(_ passphrase: String) {
        guard let loaded else { return }
        run { [self] in
            let updated = try await detached {
                try VaultService.setRecoveryPassphrase(passphrase, on: loaded)
            }
            await MainActor.run {
                self.loaded = updated
                self.recentsStore.record(updated)
            }
        }
    }

    func removeRecent(_ recent: RecentVault, forgetKey: Bool) {
        if forgetKey { VaultService.forgetStoredKey(for: recent.vaultId) }
        recentsStore.remove(vaultId: recent.vaultId)
        recents = recentsStore.all()
    }

    // MARK: - Convenience accessors

    var projects: [Project] { loaded?.contents.projects ?? [] }

    var selectedProject: Project? {
        guard let id = selectedProjectId else { return nil }
        return loaded?.contents.projects.first { $0.id == id }
    }

    // MARK: - Activity / auto-lock

    func noteActivity() { lastActivity = Date() }

    func handleSystemLockOrSleep() { if isUnlocked { lock() } }

    private func startLockTimer() {
        lockTimer?.invalidate()
        lockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkAutoLock() }
        }
    }

    private func checkAutoLock() {
        guard isUnlocked, autoLockMinutes > 0 else { return }
        if Date().timeIntervalSince(lastActivity) >= Double(autoLockMinutes * 60) {
            lock()
        }
    }

    // MARK: - Internal helpers

    private func setUnlocked(_ vault: LoadedVault) {
        self.loaded = vault
        self.phase = .unlocked
        self.selectedProjectId = vault.contents.projects.first?.id
        self.recentsStore.record(vault)
        self.recents = recentsStore.all()
        noteActivity()
    }

    /// Apply an in-memory mutation to the unlocked contents, then persist.
    private func mutate(_ change: (inout VaultContents) throws -> Void) {
        guard var loaded else { return }
        do {
            try change(&loaded.contents)
        } catch let error as VaultError {
            errorMessage = error.errorDescription
            return
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        let snapshot = loaded
        self.loaded = loaded
        noteActivity()
        run { [self] in
            let updated = try await detached { try VaultService.save(snapshot) }
            await MainActor.run {
                // Preserve newer in-memory edits; just refresh metadata.
                self.loaded?.modifiedAt = updated.modifiedAt
            }
        }
    }

    /// Run a throwing async block, surfacing errors and toggling the busy flag.
    private func run(_ work: @escaping () async throws -> Void) {
        isBusy = true
        Task {
            defer { self.isBusy = false }
            do {
                try await work()
            } catch let error as VaultError {
                self.errorMessage = error.errorDescription
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// Run blocking VaultaCore work off the main thread.
    private func detached<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated) { try work() }.value
    }
}
