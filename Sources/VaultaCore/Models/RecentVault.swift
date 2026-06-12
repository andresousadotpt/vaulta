import Foundation

/// A lightweight, non-secret reference to a vault file the user has opened.
/// Stored in UserDefaults so the app can show "Open Recent" and reopen the
/// last-used vault on launch. Contains no secret material.
public struct RecentVault: Codable, Identifiable, Equatable, Sendable {
    public var vaultId: UUID
    public var name: String
    public var path: String
    public var bookmark: Data?
    public var lastOpened: Date

    public var id: UUID { vaultId }
    public var url: URL { URL(fileURLWithPath: path) }
    public var exists: Bool { FileManager.default.fileExists(atPath: path) }

    public init(
        vaultId: UUID,
        name: String,
        path: String,
        bookmark: Data? = nil,
        lastOpened: Date = Date()
    ) {
        self.vaultId = vaultId
        self.name = name
        self.path = path
        self.bookmark = bookmark
        self.lastOpened = lastOpened
    }
}
