import Foundation

/// Mutation helpers with the invariants Vaulta enforces: unique project names
/// (case-insensitive) and unique secret keys within a project.
extension VaultContents {

    // MARK: - Projects

    @discardableResult
    public mutating func addProject(name: String) throws -> Project {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try ensureUniqueProjectName(trimmed, excluding: nil)
        let project = Project(name: trimmed)
        projects.append(project)
        return project
    }

    public mutating func renameProject(id: UUID, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try ensureUniqueProjectName(trimmed, excluding: id)
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].name = trimmed
        projects[idx].updatedAt = Date()
    }

    public mutating func deleteProject(id: UUID) {
        projects.removeAll { $0.id == id }
    }

    private func ensureUniqueProjectName(_ name: String, excluding id: UUID?) throws {
        let clash = projects.contains {
            $0.id != id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
        if clash { throw VaultError.duplicateProjectName(name) }
    }

    // MARK: - Secrets

    @discardableResult
    public mutating func addSecret(
        toProject projectId: UUID,
        key: String,
        value: String,
        note: String = ""
    ) throws -> Secret {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else {
            throw VaultError.duplicateProjectName("") // unreachable in practice
        }
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try ensureUniqueSecretKey(trimmedKey, in: idx, excluding: nil)
        let secret = Secret(key: trimmedKey, value: value, note: note)
        projects[idx].secrets.append(secret)
        projects[idx].updatedAt = Date()
        return secret
    }

    public mutating func updateSecret(
        inProject projectId: UUID,
        secretId: UUID,
        key: String,
        value: String,
        note: String
    ) throws {
        guard let pIdx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try ensureUniqueSecretKey(trimmedKey, in: pIdx, excluding: secretId)
        guard let sIdx = projects[pIdx].secrets.firstIndex(where: { $0.id == secretId }) else { return }
        projects[pIdx].secrets[sIdx].key = trimmedKey
        projects[pIdx].secrets[sIdx].value = value
        projects[pIdx].secrets[sIdx].note = note
        projects[pIdx].secrets[sIdx].updatedAt = Date()
        projects[pIdx].updatedAt = Date()
    }

    public mutating func deleteSecret(inProject projectId: UUID, secretId: UUID) {
        guard let pIdx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[pIdx].secrets.removeAll { $0.id == secretId }
        projects[pIdx].updatedAt = Date()
    }

    private func ensureUniqueSecretKey(_ key: String, in projectIndex: Int, excluding id: UUID?) throws {
        let clash = projects[projectIndex].secrets.contains {
            $0.id != id && $0.key.localizedCaseInsensitiveCompare(key) == .orderedSame
        }
        if clash { throw VaultError.duplicateSecretKey(key) }
    }
}
