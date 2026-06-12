import Foundation

/// A single key/value secret. `value` is only ever held in memory after the
/// containing vault has been decrypted; it is never written to disk in plaintext.
public struct Secret: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var key: String
    public var value: String
    public var note: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        key: String,
        value: String,
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
