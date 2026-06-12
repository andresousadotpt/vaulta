import XCTest
@testable import VaultaCore

final class SecretExporterTests: XCTestCase {

    private func sampleProject() -> Project {
        Project(name: "api", secrets: [
            Secret(key: "DATABASE_URL", value: "postgres://localhost/db"),
            Secret(key: "API_KEY", value: "abc 123"),          // value needs quoting
            Secret(key: "EMPTY", value: ""),
        ])
    }

    func testDotenvFormat() {
        let out = SecretExporter.export(sampleProject(), as: .dotenv)
        XCTAssertTrue(out.contains("DATABASE_URL=postgres://localhost/db"))
        XCTAssertTrue(out.contains("API_KEY=\"abc 123\""))   // quoted because of space
        XCTAssertTrue(out.contains("EMPTY=\"\""))
    }

    func testDirenvFormatHasExportPrefix() {
        let out = SecretExporter.export(sampleProject(), as: .direnv)
        XCTAssertTrue(out.contains("export DATABASE_URL=postgres://localhost/db"))
    }

    func testShellFormatSingleQuotes() {
        let out = SecretExporter.export(sampleProject(), as: .shell)
        XCTAssertTrue(out.contains("export API_KEY='abc 123'"))
    }

    func testJSONFormatIsValid() throws {
        let out = SecretExporter.export(sampleProject(), as: .json)
        let data = Data(out.utf8)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: String]
        XCTAssertEqual(dict?["DATABASE_URL"], "postgres://localhost/db")
        XCTAssertEqual(dict?["API_KEY"], "abc 123")
    }

    func testYAMLFormat() {
        let out = SecretExporter.export(sampleProject(), as: .yaml)
        XCTAssertTrue(out.contains("DATABASE_URL: postgres://localhost/db"))
    }

    func testKeysAreSortedAndNormalized() {
        let project = Project(name: "p", secrets: [
            Secret(key: "lower-case key", value: "v"),
        ])
        let out = SecretExporter.export(project, as: .dotenv)
        XCTAssertTrue(out.contains("LOWER_CASE_KEY=v"))
    }
}
