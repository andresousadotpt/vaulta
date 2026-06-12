import SwiftUI
import AppKit
import VaultaCore

/// Lists the secrets in a project with reveal / copy / edit / delete.
struct SecretsListView: View {
    @Environment(AppState.self) private var app
    let project: Project

    @State private var revealed: Set<UUID> = []
    @State private var editingSecret: Secret?
    @State private var addingSecret = false
    @State private var deleting: Secret?
    @State private var search = ""

    private var filtered: [Secret] {
        let items = project.secrets.sorted {
            $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
        }
        guard !search.isEmpty else { return items }
        return items.filter {
            $0.key.localizedCaseInsensitiveContains(search) ||
            $0.note.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        Group {
            if project.secrets.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filtered) { secret in
                        SecretRow(
                            secret: secret,
                            isRevealed: revealed.contains(secret.id),
                            onToggleReveal: { toggleReveal(secret.id) },
                            onCopy: { copy(secret.value) },
                            onEdit: { editingSecret = secret },
                            onDelete: { deleting = secret }
                        )
                        // Pin each row's identity to the secret so re-sorting on
                        // add doesn't reassign a row view (and its @State) to a
                        // different secret — which left stale layout and stuck
                        // hover highlights.
                        .id(secret.id)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .searchable(text: $search, placement: .toolbar, prompt: "Filter secrets")
            }
        }
        .navigationTitle(project.name)
        .navigationSubtitle("\(project.secrets.count) secret\(project.secrets.count == 1 ? "" : "s")")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { addingSecret = true } label: {
                    Label("Add Secret", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .onChange(of: project.id) { _, _ in revealed.removeAll(); search = "" }
        .sheet(isPresented: $addingSecret) {
            SecretEditorView(projectId: project.id, existing: nil)
        }
        .sheet(item: $editingSecret) { secret in
            SecretEditorView(projectId: project.id, existing: secret)
        }
        .alert("Delete secret?", isPresented: Binding(
            get: { deleting != nil },
            set: { if !$0 { deleting = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) {
                if let s = deleting { app.deleteSecret(inProject: project.id, secretId: s.id) }
                deleting = nil
            }
        } message: {
            Text("\"\(deleting?.key ?? "")\" will be permanently removed.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "key.horizontal")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No secrets in \(project.name)").font(.title3)
            Button("Add a secret") { addingSecret = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggleReveal(_ id: UUID) {
        app.noteActivity()
        if revealed.contains(id) { revealed.remove(id) } else { revealed.insert(id) }
    }

    private func copy(_ value: String) {
        app.noteActivity()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
    }
}

private struct SecretRow: View {
    let secret: Secret
    let isRevealed: Bool
    let onToggleReveal: () -> Void
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    /// A fixed-width mask: uniform across rows and doesn't leak the value length.
    private static let mask = String(repeating: "•", count: 14)

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(secret.key)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Text(isRevealed ? secret.value : Self.mask)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(isRevealed ? .primary : .secondary)
                    .textSelection(.enabled)
                    .lineLimit(isRevealed ? 4 : 1)
                if !secret.note.isEmpty {
                    Text(secret.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                iconButton(isRevealed ? "eye.slash" : "eye", help: isRevealed ? "Hide" : "Reveal", action: onToggleReveal)
                iconButton("doc.on.doc", help: "Copy value", action: onCopy)
                iconButton("pencil", help: "Edit", action: onEdit)
                iconButton("trash", help: "Delete", role: .destructive, action: onDelete)
            }
            .opacity(hovering ? 1 : 0.45)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 40)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        // A row view can be reassigned to a different secret when the list
        // re-sorts; reset hover so it doesn't stay stuck bright.
        .onChange(of: secret.id) { _, _ in hovering = false }
        .contextMenu {
            Button(isRevealed ? "Hide" : "Reveal", action: onToggleReveal)
            Button("Copy Value", action: onCopy)
            Button("Edit…", action: onEdit)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private func iconButton(_ name: String, help: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Image(systemName: name)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}
