import Foundation
import CryptoKit

/// All cryptographic primitives for Vaulta, built only on Apple's CryptoKit.
///
/// - Symmetric encryption: AES-256-GCM (authenticated encryption).
/// - Key derivation from a passphrase: PBKDF2-HMAC-SHA256, implemented directly
///   on CryptoKit's `HMAC` so there is no dependency on CommonCrypto.
public enum CryptoService {

    public static let defaultPBKDF2Iterations = 600_000
    public static let saltByteCount = 32

    // MARK: - Random material

    /// A fresh random 256-bit Data Encryption Key.
    public static func generateDataKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    public static func randomSalt(count: Int = saltByteCount) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        for i in 0..<count { bytes[i] = UInt8.random(in: .min ... .max) }
        return Data(bytes)
    }

    // MARK: - Symmetric encryption (AES-256-GCM)

    /// Seal `plaintext` with `key`. Returns the AES-GCM combined box
    /// (nonce ‖ ciphertext ‖ tag).
    public static func seal(_ plaintext: Data, with key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw VaultError.decryptionFailed
        }
        return combined
    }

    /// Open an AES-GCM combined box produced by `seal`.
    public static func open(_ box: Data, with key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: box)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw VaultError.decryptionFailed
        }
    }

    // MARK: - Key wrapping (passphrase path)

    public static func deriveKey(
        passphrase: String,
        salt: Data,
        iterations: Int = defaultPBKDF2Iterations
    ) -> SymmetricKey {
        let passwordBytes = Array(passphrase.utf8)
        let derived = pbkdf2SHA256(
            password: passwordBytes,
            salt: Array(salt),
            iterations: iterations,
            keyByteCount: 32
        )
        return SymmetricKey(data: derived)
    }

    /// Wrap (encrypt) the raw DEK bytes under a passphrase-derived KEK.
    public static func wrapKey(
        _ dataKey: SymmetricKey,
        passphrase: String,
        salt: Data,
        iterations: Int = defaultPBKDF2Iterations
    ) throws -> Data {
        let kek = deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        let raw = dataKey.withUnsafeBytes { Data($0) }
        return try seal(raw, with: kek)
    }

    /// Unwrap (decrypt) the DEK using the passphrase. Throws `.wrongPassphrase`
    /// if authentication fails.
    public static func unwrapKey(
        _ wrapped: Data,
        passphrase: String,
        salt: Data,
        iterations: Int = defaultPBKDF2Iterations
    ) throws -> SymmetricKey {
        let kek = deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        do {
            let raw = try open(wrapped, with: kek)
            return SymmetricKey(data: raw)
        } catch {
            throw VaultError.wrongPassphrase
        }
    }

    // MARK: - PBKDF2 (RFC 8018) on CryptoKit HMAC-SHA256

    private static func pbkdf2SHA256(
        password: [UInt8],
        salt: [UInt8],
        iterations: Int,
        keyByteCount: Int
    ) -> Data {
        let key = SymmetricKey(data: password)
        let hLen = SHA256.byteCount // 32
        let blockCount = Int(ceil(Double(keyByteCount) / Double(hLen)))
        var derived = [UInt8]()
        derived.reserveCapacity(blockCount * hLen)

        for block in 1...max(blockCount, 1) {
            // INT_32_BE(block)
            var blockIndex = UInt32(block).bigEndian
            var saltBlock = salt
            withUnsafeBytes(of: &blockIndex) { saltBlock.append(contentsOf: $0) }

            var u = hmac(key: key, data: saltBlock)
            var t = u
            if iterations > 1 {
                for _ in 1..<iterations {
                    u = hmac(key: key, data: u)
                    for i in 0..<t.count { t[i] ^= u[i] }
                }
            }
            derived.append(contentsOf: t)
        }

        return Data(derived.prefix(keyByteCount))
    }

    private static func hmac(key: SymmetricKey, data: [UInt8]) -> [UInt8] {
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Array(mac)
    }
}
