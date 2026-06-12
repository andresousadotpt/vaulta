import SwiftUI
import AppKit
import VaultaCore

/// Preview and export a project's secrets in a developer-friendly format.
struct ExportSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let project: Project

    @State private var format: SecretExporter.Format = .dotenv
    @State private var copied = false

    private var rendered: String {
        SecretExporter.export(project, as: format)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Secrets").font(.title2).bold()
                    Text("\(project.name) · \(project.secrets.count) secret\(project.secrets.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            Picker("Format", selection: $format) {
                ForEach(SecretExporter.Format.allCases) { f in
                    Text(f.displayName).tag(f)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 240, alignment: .leading)

            ScrollView {
                Text(rendered.isEmpty ? "# No secrets to export" : rendered)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(height: 240)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))

            Label("Exported files are written in plaintext. Handle them like any secret.",
                  systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)

            HStack {
                Button {
                    copyToClipboard()
                } label: {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save to File…") { saveToFile() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 540)
    }

    private func copyToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(rendered, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }

    private func saveToFile() {
        guard let url = FilePanels.chooseExportDestination(suggestedName: format.suggestedFileName) else { return }
        do {
            try rendered.data(using: .utf8)?.write(to: url, options: [.atomic])
            dismiss()
        } catch {
            app.errorMessage = "Could not write export: \(error.localizedDescription)"
        }
    }
}
