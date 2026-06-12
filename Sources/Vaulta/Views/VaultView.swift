import SwiftUI
import VaultaCore

/// The main working surface for an unlocked vault: projects on the left, the
/// selected project's secrets on the right.
struct VaultView: View {
    @Environment(AppState.self) private var app

    @State private var showingNewProject = false
    @State private var newProjectName = ""
    @State private var renamingProject: Project?
    @State private var renameText = ""
    @State private var showingExport = false
    @State private var showingRenameVault = false
    @State private var renameVaultText = ""
    @State private var showingPassphrase = false

    var body: some View {
        NavigationSplitView {
            ProjectSidebar(
                onAdd: { showingNewProject = true },
                onRename: { project in
                    renamingProject = project
                    renameText = project.name
                }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            if let project = app.selectedProject {
                SecretsListView(project: project)
            } else {
                EmptyProjectState(hasProjects: !app.projects.isEmpty) {
                    showingNewProject = true
                }
            }
        }
        .toolbar { toolbarContent }
        .contentShape(Rectangle())
        .onTapGesture { app.noteActivity() }
        // New project
        .alert("New Project", isPresented: $showingNewProject) {
            TextField("Project name", text: $newProjectName)
            Button("Cancel", role: .cancel) { newProjectName = "" }
            Button("Create") {
                app.addProject(name: newProjectName)
                newProjectName = ""
            }
        } message: {
            Text("Group related secrets together (e.g. an app or environment).")
        }
        // Rename project
        .alert("Rename Project", isPresented: Binding(
            get: { renamingProject != nil },
            set: { if !$0 { renamingProject = nil } }
        )) {
            TextField("Project name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingProject = nil }
            Button("Rename") {
                if let p = renamingProject { app.renameProject(id: p.id, to: renameText) }
                renamingProject = nil
            }
        }
        .sheet(isPresented: $showingExport) {
            if let project = app.selectedProject {
                ExportSheet(project: project)
            }
        }
        .sheet(isPresented: $showingPassphrase) {
            RecoveryPassphraseSheet()
        }
        // Rename vault
        .alert("Rename Vault", isPresented: $showingRenameVault) {
            TextField("Vault name", text: $renameVaultText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { app.renameVault(to: renameVaultText) }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 8) {
                BrandMark(size: 18)
                Text(app.currentVaultName).fontWeight(.semibold)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
        ToolbarItemGroup {
            if app.selectedProject != nil {
                Button {
                    showingExport = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export secrets as .env, direnv, JSON, and more")
            }

            Menu {
                VaultMenu(
                    onRenameVault: {
                        renameVaultText = app.currentVaultName
                        showingRenameVault = true
                    },
                    onSetPassphrase: { showingPassphrase = true }
                )
            } label: {
                Label("Vault", systemImage: "ellipsis.circle")
            }

            Button {
                app.lock()
            } label: {
                Label("Lock", systemImage: "lock.fill")
            }
            .help("Lock vault (⇧⌘L)")
        }
    }
}

private struct EmptyProjectState: View {
    let hasProjects: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: hasProjects ? "folder" : "folder.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text(hasProjects ? "Select a project" : "No projects yet")
                .font(.title3)
            if !hasProjects {
                Button("Create your first project", action: onCreate)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
