import Foundation

/// The decrypted contents of a vault. This is the plaintext payload that gets
/// sealed with AES-256-GCM before it ever touches disk.
public struct VaultContents: Codable, Equatable, Sendable {
    public var vaultId: UUID
    public var name: String
    public var projects: [Project]

    public init(vaultId: UUID = UUID(), name: String, projects: [Project] = []) {
        self.vaultId = vaultId
        self.name = name
        self.projects = projects
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decoded(from data: Data) throws -> VaultContents {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VaultContents.self, from: data)
    }
}
