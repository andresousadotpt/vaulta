import Foundation

/// Persists the list of recently-opened vaults and the last-active vault id.
/// Backed by UserDefaults; holds only file references, never secrets.
public final class RecentVaultsStore: @unchecked Sendable {

    public static let shared = RecentVaultsStore()

    private let defaults: UserDefaults
    private let recentsKey = "vaulta.recentVaults"
    private let lastActiveKey = "vaulta.lastActiveVaultId"
    private let maxRecents = 10

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Recents

    public func all() -> [RecentVault] {
        guard let data = defaults.data(forKey: recentsKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let list = (try? decoder.decode([RecentVault].self, from: data)) ?? []
        return list.sorted { $0.lastOpened > $1.lastOpened }
    }

    public func record(_ vault: LoadedVault) {
        let bookmark = try? vault.url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let entry = RecentVault(
            vaultId: vault.vaultId,
            name: vault.contents.name,
            path: vault.url.path,
            bookmark: bookmark,
            lastOpened: Date()
        )
        var list = all().filter { $0.vaultId != entry.vaultId && $0.path != entry.path }
        list.insert(entry, at: 0)
        if list.count > maxRecents { list = Array(list.prefix(maxRecents)) }
        persist(list)
        setLastActive(entry.vaultId)
    }

    public func remove(vaultId: UUID) {
        persist(all().filter { $0.vaultId != vaultId })
        if lastActiveVaultId() == vaultId { defaults.removeObject(forKey: lastActiveKey) }
    }

    public func clear() {
        defaults.removeObject(forKey: recentsKey)
        defaults.removeObject(forKey: lastActiveKey)
    }

    private func persist(_ list: [RecentVault]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(list) {
            defaults.set(data, forKey: recentsKey)
        }
    }

    // MARK: - Last active

    public func lastActiveVaultId() -> UUID? {
        guard let s = defaults.string(forKey: lastActiveKey) else { return nil }
        return UUID(uuidString: s)
    }

    public func setLastActive(_ vaultId: UUID) {
        defaults.set(vaultId.uuidString, forKey: lastActiveKey)
    }

    public func lastActiveVault() -> RecentVault? {
        guard let id = lastActiveVaultId() else { return nil }
        return all().first { $0.vaultId == id }
    }
}
