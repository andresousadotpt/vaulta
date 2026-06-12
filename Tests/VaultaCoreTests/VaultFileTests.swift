import XCTest
@testable import VaultaCore

final class VaultFileTests: XCTestCase {

    private func makeFile() -> VaultFile {
        VaultFile(
            vaultId: UUID(),
            name: "Test",
            createdAt: Date(),
            modifiedAt: Date(),
            kdf: nil,
            wrappedKey: nil,
            payload: Data("ciphertext".utf8)
        )
    }

    func testSerializeRoundTrip() throws {
        let original = makeFile()
        let restored = try VaultFile.deserialize(try original.serialized())
        XCTAssertEqual(restored.vaultId, original.vaultId)
        XCTAssertEqual(restored.magic, VaultFile.magic)
    }

    /// A file that isn't a Vaulta envelope (e.g. an unrelated file renamed to
    /// `.vaulta`) must surface the friendly `notAVaultaFile` error rather than a
    /// raw Foundation DecodingError.
    func testNonVaultaFileGivesClearError() {
        let notAVault = Data("just some random text, not JSON".utf8)
        XCTAssertThrowsError(try VaultFile.deserialize(notAVault)) { error in
            XCTAssertEqual(error as? VaultError, .notAVaultaFile)
        }
    }

    /// Valid JSON that lacks the Vaulta fields is also not a vault.
    func testWrongShapedJSONGivesClearError() {
        let otherJSON = Data(#"{"hello":"world"}"#.utf8)
        XCTAssertThrowsError(try VaultFile.deserialize(otherJSON)) { error in
            XCTAssertEqual(error as? VaultError, .notAVaultaFile)
        }
    }

    /// Valid Vaulta JSON but with a wrong magic value is rejected.
    func testWrongMagicRejected() throws {
        var data = try makeFile().serialized()
        let json = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "VAULTA", with: "NOTVLT")
        data = Data(json.utf8)
        XCTAssertThrowsError(try VaultFile.deserialize(data)) { error in
            XCTAssertEqual(error as? VaultError, .notAVaultaFile)
        }
    }
}
