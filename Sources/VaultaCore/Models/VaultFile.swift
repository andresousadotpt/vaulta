import Foundation

/// The on-disk, fully-encrypted representation of a vault (the `.vaulta` file).
///
/// Nothing sensitive is stored in plaintext here:
/// - `payload` is the vault contents sealed with AES-256-GCM under the DEK.
/// - `wrappedKey` (optional) is the DEK sealed with a passphrase-derived KEK.
///   It only exists when the user opts into a recovery passphrase.
///
/// The DEK itself lives in the Keychain behind biometric/device-password access
/// control and is never serialized into this file.
public struct VaultFile: Codable, Equatable, Sendable {
    public static let magic = "VAULTA"
    public static let currentFormatVersion = 1

    public struct KDFParameters: Codable, Equatable, Sendable {
        public var algorithm: String      // "PBKDF2-HMAC-SHA256"
        public var salt: Data
        public var iterations: Int

        public init(algorithm: String, salt: Data, iterations: Int) {
            self.algorithm = algorithm
            self.salt = salt
            self.iterations = iterations
        }
    }

    public var magic: String
    public var formatVersion: Int
    public var vaultId: UUID
    public var name: String
    public var createdAt: Date
    public var modifiedAt: Date

    /// Present when the user set a recovery passphrase.
    public var kdf: KDFParameters?
    /// DEK encrypted under the passphrase-derived KEK (AES-256-GCM combined box).
    public var wrappedKey: Data?

    /// Vault contents encrypted under the DEK (AES-256-GCM combined box).
    public var payload: Data

    public init(
        vaultId: UUID,
        name: String,
        createdAt: Date,
        modifiedAt: Date,
        kdf: KDFParameters?,
        wrappedKey: Data?,
        payload: Data
    ) {
        self.magic = VaultFile.magic
        self.formatVersion = VaultFile.currentFormatVersion
        self.vaultId = vaultId
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.kdf = kdf
        self.wrappedKey = wrappedKey
        self.payload = payload
    }

    public var hasRecoveryPassphrase: Bool { wrappedKey != nil && kdf != nil }

    public func serialized() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func deserialize(_ data: Data) throws -> VaultFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file: VaultFile
        do {
            file = try decoder.decode(VaultFile.self, from: data)
        } catch {
            // The file isn't a Vaulta envelope at all (not JSON, missing fields,
            // truncated, …). Surface a clear message instead of Foundation's
            // generic "data couldn't be read because it isn't in the correct
            // format", which a DecodingError would otherwise produce.
            throw VaultError.notAVaultaFile
        }
        guard file.magic == VaultFile.magic else {
            throw VaultError.notAVaultaFile
        }
        guard file.formatVersion <= VaultFile.currentFormatVersion else {
            throw VaultError.unsupportedFormatVersion(file.formatVersion)
        }
        return file
    }
}
