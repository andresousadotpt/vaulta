import Foundation
import CryptoKit

/// The in-memory state of an unlocked vault. The `dataKey` lives only here while
/// the vault is open and is dropped the moment the vault is locked.
public struct LoadedVault: Sendable {
    public var url: URL
    public var vaultId: UUID
    public var createdAt: Date
    public var modifiedAt: Date
    public var kdf: VaultFile.KDFParameters?
    public var wrappedKey: Data?
    public var dataKey: SymmetricKey
    public var contents: VaultContents

    public var hasRecoveryPassphrase: Bool { wrappedKey != nil && kdf != nil }

    public init(
        url: URL,
        vaultId: UUID,
        createdAt: Date,
        modifiedAt: Date,
        kdf: VaultFile.KDFParameters?,
        wrappedKey: Data?,
        dataKey: SymmetricKey,
        contents: VaultContents
    ) {
        self.url = url
        self.vaultId = vaultId
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.kdf = kdf
        self.wrappedKey = wrappedKey
        self.dataKey = dataKey
        self.contents = contents
    }
}
