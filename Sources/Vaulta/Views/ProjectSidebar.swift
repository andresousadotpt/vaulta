import SwiftUI
import VaultaCore

/// Sidebar listing the vault's projects with add / rename / delete.
struct ProjectSidebar: View {
    @Environment(AppState.self) private var app
    let onAdd: () -> Void
    let onRename: (Project) -> Void

    @State private var deleting: Project?

    var body: some View {
        @Bindable var app = app
        List(selection: $app.selectedProjectId) {
            Section("Projects") {
                ForEach(app.projects) { project in
                    Label {
                        HStack {
                            Text(project.name)
                            Spacer()
                            Text("\(project.secrets.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    } icon: {
                        Image(systemName: "folder.fill")
                    }
                    .tag(project.id)
                    .contextMenu {
                        Button("Rename…") { onRename(project) }
                        Button("Delete", role: .destructive) { deleting = project }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onAdd) {
                Label("New Project", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
        .alert("Delete project?", isPresented: Binding(
            get: { deleting != nil },
            set: { if !$0 { deleting = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) {
                if let p = deleting { app.deleteProject(id: p.id) }
                deleting = nil
            }
        } message: {
            Text("\"\(deleting?.name ?? "")\" and all its secrets will be permanently removed.")
        }
    }
}
