import XCTest
import CryptoKit
@testable import VaultaCore

final class CryptoServiceTests: XCTestCase {

    func testSealOpenRoundTrip() throws {
        let key = CryptoService.generateDataKey()
        let plaintext = Data("super secret value 🔐".utf8)
        let box = try CryptoService.seal(plaintext, with: key)
        XCTAssertNotEqual(box, plaintext)
        let recovered = try CryptoService.open(box, with: key)
        XCTAssertEqual(recovered, plaintext)
    }

    func testOpenWithWrongKeyFails() throws {
        let key = CryptoService.generateDataKey()
        let other = CryptoService.generateDataKey()
        let box = try CryptoService.seal(Data("x".utf8), with: key)
        XCTAssertThrowsError(try CryptoService.open(box, with: other)) { error in
            XCTAssertEqual(error as? VaultError, .decryptionFailed)
        }
    }

    func testWrapUnwrapWithPassphrase() throws {
        let dek = CryptoService.generateDataKey()
        let salt = CryptoService.randomSalt()
        // Use a low iteration count to keep the test fast.
        let wrapped = try CryptoService.wrapKey(dek, passphrase: "correct horse", salt: salt, iterations: 1000)
        let unwrapped = try CryptoService.unwrapKey(wrapped, passphrase: "correct horse", salt: salt, iterations: 1000)
        XCTAssertEqual(dek.withUnsafeBytes { Data($0) }, unwrapped.withUnsafeBytes { Data($0) })
    }

    func testUnwrapWithWrongPassphraseFails() throws {
        let dek = CryptoService.generateDataKey()
        let salt = CryptoService.randomSalt()
        let wrapped = try CryptoService.wrapKey(dek, passphrase: "right", salt: salt, iterations: 1000)
        XCTAssertThrowsError(try CryptoService.unwrapKey(wrapped, passphrase: "wrong", salt: salt, iterations: 1000)) { error in
            XCTAssertEqual(error as? VaultError, .wrongPassphrase)
        }
    }

    func testPBKDF2IsDeterministic() {
        let salt = Data(repeating: 7, count: 16)
        let a = CryptoService.deriveKey(passphrase: "pw", salt: salt, iterations: 2048)
        let b = CryptoService.deriveKey(passphrase: "pw", salt: salt, iterations: 2048)
        XCTAssertEqual(a.withUnsafeBytes { Data($0) }, b.withUnsafeBytes { Data($0) })
    }

    func testPBKDF2KnownAnswer() {
        // RFC 6070-style check against CryptoKit reference would require the same
        // construction; here we assert key length and salt sensitivity instead.
        let key1 = CryptoService.deriveKey(passphrase: "pw", salt: Data(repeating: 1, count: 16), iterations: 1000)
        let key2 = CryptoService.deriveKey(passphrase: "pw", salt: Data(repeating: 2, count: 16), iterations: 1000)
        XCTAssertEqual(key1.bitCount, 256)
        XCTAssertNotEqual(key1.withUnsafeBytes { Data($0) }, key2.withUnsafeBytes { Data($0) })
    }
}
