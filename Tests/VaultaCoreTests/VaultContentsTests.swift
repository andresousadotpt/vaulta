import XCTest
@testable import VaultaCore

final class VaultContentsTests: XCTestCase {

    func testEncodeDecodeRoundTrip() throws {
        var contents = VaultContents(name: "Test")
        let project = try contents.addProject(name: "api")
        try contents.addSecret(toProject: project.id, key: "TOKEN", value: "abc123")
        let data = try contents.encoded()
        let decoded = try VaultContents.decoded(from: data)
        // ISO8601 truncates sub-second precision, so the original (in-memory) and
        // decoded values aren't byte-identical. The stable invariant is that once
        // decoded, the value round-trips to itself.
        let redecoded = try VaultContents.decoded(from: try decoded.encoded())
        XCTAssertEqual(decoded, redecoded)
        XCTAssertEqual(decoded.name, "Test")
        XCTAssertEqual(decoded.vaultId, contents.vaultId)
        XCTAssertEqual(decoded.projects.first?.secrets.first?.value, "abc123")
    }

    func testDuplicateProjectNameRejected() throws {
        var contents = VaultContents(name: "Test")
        try contents.addProject(name: "Billing")
        XCTAssertThrowsError(try contents.addProject(name: "billing")) { error in
            XCTAssertEqual(error as? VaultError, .duplicateProjectName("billing"))
        }
    }

    func testDuplicateSecretKeyRejected() throws {
        var contents = VaultContents(name: "Test")
        let p = try contents.addProject(name: "api")
        try contents.addSecret(toProject: p.id, key: "KEY", value: "1")
        XCTAssertThrowsError(try contents.addSecret(toProject: p.id, key: "key", value: "2")) { error in
            XCTAssertEqual(error as? VaultError, .duplicateSecretKey("key"))
        }
    }

    func testUpdateAndDeleteSecret() throws {
        var contents = VaultContents(name: "Test")
        let p = try contents.addProject(name: "api")
        let s = try contents.addSecret(toProject: p.id, key: "KEY", value: "1")
        try contents.updateSecret(inProject: p.id, secretId: s.id, key: "KEY2", value: "2", note: "n")
        XCTAssertEqual(contents.projects[0].secrets[0].key, "KEY2")
        XCTAssertEqual(contents.projects[0].secrets[0].value, "2")
        contents.deleteSecret(inProject: p.id, secretId: s.id)
        XCTAssertTrue(contents.projects[0].secrets.isEmpty)
    }

    func testDeleteProject() throws {
        var contents = VaultContents(name: "Test")
        let p = try contents.addProject(name: "api")
        contents.deleteProject(id: p.id)
        XCTAssertTrue(contents.projects.isEmpty)
    }
}
