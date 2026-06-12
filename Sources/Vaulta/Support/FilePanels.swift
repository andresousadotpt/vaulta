import AppKit
import UniformTypeIdentifiers
import VaultaCore

/// AppKit save/open panel wrappers for picking vault locations and export files.
@MainActor
enum FilePanels {

    static var vaultType: UTType {
        UTType(filenameExtension: VaultService.fileExtension) ?? .data
    }

    /// Ask the user where to create a new vault — returns the chosen file URL,
    /// with the `.vaulta` extension enforced.
    static func chooseNewVaultFile(defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Create Vault"
        panel.prompt = "Create"
        panel.nameFieldStringValue = "\(defaultName).\(VaultService.fileExtension)"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [vaultType]
        guard panel.runModal() == .OK, var url = panel.url else { return nil }
        if url.pathExtension != VaultService.fileExtension {
            url.appendPathExtension(VaultService.fileExtension)
        }
        return url
    }

    /// Pick an existing `.vaulta` file to open.
    static func chooseExistingVault() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open Vault"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [vaultType]
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    /// Pick a destination for an exported secrets file.
    static func chooseExportDestination(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Secrets"
        panel.prompt = "Export"
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
