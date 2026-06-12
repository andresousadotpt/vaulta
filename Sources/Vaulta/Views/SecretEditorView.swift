import SwiftUI
import VaultaCore

/// Add or edit a single secret.
struct SecretEditorView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID
    let existing: Secret?

    @State private var key = ""
    @State private var value = ""
    @State private var note = ""
    @State private var reveal = false

    private var isEditing: Bool { existing != nil }
    private var canSave: Bool {
        !key.trimmingCharacters(in: .whitespaces).isEmpty && !value.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Edit Secret" : "New Secret")
                .font(.title2).bold()

            VStack(alignment: .leading, spacing: 6) {
                Text("Key").font(.subheadline).foregroundStyle(.secondary)
                TextField("e.g. DATABASE_URL", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Value").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Toggle("Show", isOn: $reveal).toggleStyle(.button).controlSize(.small)
                }
                if reveal {
                    TextEditor(text: $value)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 80)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))
                } else {
                    SecureField("secret value", text: $value)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Note (optional)").font(.subheadline).foregroundStyle(.secondary)
                TextField("What is this for?", text: $note)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear {
            if let existing {
                key = existing.key
                value = existing.value
                note = existing.note
            }
        }
    }

    private func save() {
        if let existing {
            app.updateSecret(inProject: projectId, secretId: existing.id, key: key, value: value, note: note)
        } else {
            app.addSecret(toProject: projectId, key: key, value: value, note: note)
        }
        dismiss()
    }
}
