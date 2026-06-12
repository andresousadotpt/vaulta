import Foundation

/// Helpers for writing user data safely — always atomic, never a partial file.
public enum AtomicFile {
    public static func write(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            throw VaultError.fileWriteFailed(error.localizedDescription)
        }
    }

    public static func read(_ url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw VaultError.fileReadFailed(error.localizedDescription)
        }
    }
}
