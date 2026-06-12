import Foundation
import CryptoKit

/// Orchestrates the full lifecycle of a vault: create, unlock (biometric or
/// passphrase), persist, and lock. All disk writes are atomic and all secret
/// material is encrypted with AES-256-GCM before it is written.
public enum VaultService {

    public static let fileExtension = "vaulta"

    // MARK: - Create

    /// Create a brand-new vault file at `url`.
    ///
    /// A random 256-bit DEK is generated and stored in the Keychain behind
    /// biometric / device-password access control. If `passphrase` is provided,
    /// the DEK is *also* wrapped with a passphrase-derived key and embedded in
    /// the file so the vault can be recovered or opened on another Mac.
    public static func createVault(
        name: String,
        at url: URL,
        passphrase: String?
    ) throws -> LoadedVault {
        let vaultId = UUID()
        let dataKey = CryptoService.generateDataKey()
        let now = Date()
        let contents = VaultContents(vaultId: vaultId, name: name, projects: [])

        var kdf: VaultFile.KDFParameters?
        var wrappedKey: Data?
        if let passphrase, !passphrase.isEmpty {
            let salt = CryptoService.randomSalt()
            let iterations = CryptoService.defaultPBKDF2Iterations
            wrappedKey = try CryptoService.wrapKey(
                dataKey, passphrase: passphrase, salt: salt, iterations: iterations
            )
            kdf = VaultFile.KDFParameters(
                algorithm: "PBKDF2-HMAC-SHA256", salt: salt, iterations: iterations
            )
        }

        let payload = try CryptoService.seal(try contents.encoded(), with: dataKey)
        let file = VaultFile(
            vaultId: vaultId,
            name: name,
            createdAt: now,
            modifiedAt: now,
            kdf: kdf,
            wrappedKey: wrappedKey,
            payload: payload
        )

        try AtomicFile.write(try file.serialized(), to: url)
        try KeychainService.storeKey(dataKey, for: vaultId)

        return LoadedVault(
            url: url,
            vaultId: vaultId,
            createdAt: now,
            modifiedAt: now,
            kdf: kdf,
            wrappedKey: wrappedKey,
            dataKey: dataKey,
            contents: contents
        )
    }

    // MARK: - Inspect (no decryption)

    public static func readHeader(at url: URL) throws -> VaultFile {
        try VaultFile.deserialize(try AtomicFile.read(url))
    }

    public static func hasStoredKey(for vaultId: UUID) -> Bool {
        KeychainService.hasKey(for: vaultId)
    }

    // MARK: - Unlock

    /// Unlock using the Keychain-stored DEK (prompts Touch ID / device password).
    public static func unlockWithBiometrics(at url: URL, reason: String) throws -> LoadedVault {
        let file = try readHeader(at: url)
        let dataKey = try KeychainService.loadKey(for: file.vaultId, reason: reason)
        let contents = try decrypt(file: file, with: dataKey)
        return makeLoaded(url: url, file: file, dataKey: dataKey, contents: contents)
    }

    /// Unlock using the recovery passphrase. Optionally (re)store the DEK in the
    /// Keychain so future unlocks can use Touch ID.
    public static func unlockWithPassphrase(
        at url: URL,
        passphrase: String,
        storeInKeychain: Bool
    ) throws -> LoadedVault {
        let file = try readHeader(at: url)
        guard let wrapped = file.wrappedKey, let kdf = file.kdf else {
            throw VaultError.noRecoveryPassphrase
        }
        let dataKey = try CryptoService.unwrapKey(
            wrapped, passphrase: passphrase, salt: kdf.salt, iterations: kdf.iterations
        )
        let contents = try decrypt(file: file, with: dataKey)
        if storeInKeychain {
            try? KeychainService.storeKey(dataKey, for: file.vaultId)
        }
        return makeLoaded(url: url, file: file, dataKey: dataKey, contents: contents)
    }

    // MARK: - Save

    /// Re-encrypt the (possibly mutated) contents and atomically overwrite the file.
    @discardableResult
    public static func save(_ vault: LoadedVault) throws -> LoadedVault {
        let now = Date()
        let payload = try CryptoService.seal(try vault.contents.encoded(), with: vault.dataKey)
        let file = VaultFile(
            vaultId: vault.vaultId,
            name: vault.contents.name,
            createdAt: vault.createdAt,
            modifiedAt: now,
            kdf: vault.kdf,
            wrappedKey: vault.wrappedKey,
            payload: payload
        )
        try AtomicFile.write(try file.serialized(), to: vault.url)
        var updated = vault
        updated.modifiedAt = now
        return updated
    }

    // MARK: - Recovery passphrase management

    /// Set or replace the recovery passphrase on an unlocked vault.
    public static func setRecoveryPassphrase(
        _ passphrase: String,
        on vault: LoadedVault
    ) throws -> LoadedVault {
        let salt = CryptoService.randomSalt()
        let iterations = CryptoService.defaultPBKDF2Iterations
        let wrapped = try CryptoService.wrapKey(
            vault.dataKey, passphrase: passphrase, salt: salt, iterations: iterations
        )
        var updated = vault
        updated.kdf = VaultFile.KDFParameters(
            algorithm: "PBKDF2-HMAC-SHA256", salt: salt, iterations: iterations
        )
        updated.wrappedKey = wrapped
        return try save(updated)
    }

    /// Remove the device's stored key so the vault can no longer be opened with
    /// Touch ID on this Mac (used when forgetting / removing a vault).
    public static func forgetStoredKey(for vaultId: UUID) {
        try? KeychainService.deleteKey(for: vaultId)
    }

    // MARK: - Helpers

    private static func decrypt(file: VaultFile, with dataKey: SymmetricKey) throws -> VaultContents {
        let plaintext = try CryptoService.open(file.payload, with: dataKey)
        return try VaultContents.decoded(from: plaintext)
    }

    private static func makeLoaded(
        url: URL,
        file: VaultFile,
        dataKey: SymmetricKey,
        contents: VaultContents
    ) -> LoadedVault {
        LoadedVault(
            url: url,
            vaultId: file.vaultId,
            createdAt: file.createdAt,
            modifiedAt: file.modifiedAt,
            kdf: file.kdf,
            wrappedKey: file.wrappedKey,
            dataKey: dataKey,
            contents: contents
        )
    }
}
