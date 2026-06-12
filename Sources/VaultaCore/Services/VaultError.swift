import Foundation

public enum VaultError: LocalizedError, Equatable {
    case notAVaultaFile
    case unsupportedFormatVersion(Int)
    case decryptionFailed
    case wrongPassphrase
    case keyNotFound
    case keychainFailure(OSStatus)
    case biometricsUnavailable
    case authenticationFailed
    case authenticationCanceled
    case noRecoveryPassphrase
    case duplicateProjectName(String)
    case duplicateSecretKey(String)
    case fileReadFailed(String)
    case fileWriteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAVaultaFile:
            return "This file is not a valid Vaulta vault."
        case .unsupportedFormatVersion(let v):
            return "This vault uses a newer format (v\(v)) than this app supports."
        case .decryptionFailed:
            return "Could not decrypt the vault. The data may be corrupt or the key is wrong."
        case .wrongPassphrase:
            return "Incorrect recovery passphrase."
        case .keyNotFound:
            return "No encryption key is stored on this Mac for this vault."
        case .keychainFailure(let status):
            return "Keychain error (\(status))."
        case .biometricsUnavailable:
            return "Touch ID / device authentication is not available on this Mac."
        case .authenticationFailed:
            return "Authentication failed."
        case .authenticationCanceled:
            return "Authentication was canceled."
        case .noRecoveryPassphrase:
            return "This vault has no recovery passphrase set."
        case .duplicateProjectName(let name):
            return "A project named \"\(name)\" already exists."
        case .duplicateSecretKey(let key):
            return "A secret named \"\(key)\" already exists in this project."
        case .fileReadFailed(let detail):
            return "Could not read the vault file: \(detail)"
        case .fileWriteFailed(let detail):
            return "Could not save the vault file: \(detail)"
        }
    }
}
