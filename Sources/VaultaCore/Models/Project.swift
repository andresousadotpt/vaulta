import Foundation

/// A named group of secrets inside a vault (e.g. "billing-api", "staging").
public struct Project: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var secrets: [Secret]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        secrets: [Secret] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.secrets = secrets
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
