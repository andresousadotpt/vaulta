import Foundation
import Security
import LocalAuthentication
import CryptoKit

/// Stores each vault's Data Encryption Key (DEK) in the macOS Keychain, guarded
/// by an access-control policy that requires Touch ID or the device password.
///
/// Items are stored `WhenUnlockedThisDeviceOnly`, so they are never written to
/// backups or synced to iCloud — the key material cannot leave this Mac.
///
/// All operations pin `kSecUseDataProtectionKeychain = false` (the macOS
/// file-based keychain). Attaching a `kSecAttrAccessControl` object otherwise
/// implicitly opts the item into the iOS-style *data-protection* keychain,
/// which requires a `keychain-access-groups` entitlement — and that entitlement
/// can't be validated under ad-hoc signing, so the app fails to launch and the
/// Keychain calls fail with errSecMissingEntitlement (-34018). The file-based
/// keychain enforces the same Touch ID / Secure Enclave `.userPresence` ACL
/// without needing any entitlement. Every query MUST set this consistently, or
/// reads won't find what writes stored.
public enum KeychainService {

    public static let service = "pt.andresousa.vaulta"

    /// Pin operations to the macOS file-based keychain (see type doc above).
    private static let useFileKeychain = kSecUseDataProtectionKeychain as String

    private static func account(for vaultId: UUID) -> String {
        "vault.\(vaultId.uuidString)"
    }

    /// Persist the DEK for `vaultId` behind biometric / device-password access control.
    public static func storeKey(_ key: SymmetricKey, for vaultId: UUID) throws {
        let raw = key.withUnsafeBytes { Data($0) }
        let acct = account(for: vaultId)

        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &error
        ) else {
            throw VaultError.keychainFailure(errSecParam)
        }

        // Replace any existing entry first.
        try? deleteKey(for: vaultId)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acct,
            kSecValueData as String: raw,
            kSecAttrAccessControl as String: access,
            useFileKeychain: false,
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultError.keychainFailure(status)
        }
    }

    /// Retrieve the DEK, prompting for Touch ID / device password with `reason`.
    public static func loadKey(for vaultId: UUID, reason: String) throws -> SymmetricKey {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Password"
        context.localizedReason = reason

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: vaultId),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
            useFileKeychain: false,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw VaultError.keyNotFound
            }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            throw VaultError.keyNotFound
        case errSecUserCanceled:
            throw VaultError.authenticationCanceled
        case errSecAuthFailed:
            throw VaultError.authenticationFailed
        default:
            throw VaultError.keychainFailure(status)
        }
    }

    /// Whether a key is stored for this vault on this Mac (no auth prompt).
    public static func hasKey(for vaultId: UUID) -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: vaultId),
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
            useFileKeychain: false,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        // errSecInteractionNotAllowed means the item exists but needs auth to read.
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    public static func deleteKey(for vaultId: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: vaultId),
            useFileKeychain: false,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VaultError.keychainFailure(status)
        }
    }
}
