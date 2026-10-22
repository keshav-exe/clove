import SwiftUI

struct SecretDetailView: View {
    @Environment(AppModel.self) private var model
    let name: String

    @State private var revealed: String?
    @State private var isConfirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    Text(name)
                        .font(.title2.monospaced().weight(.semibold))
                        .textSelection(.enabled)
                    Label("In your login Keychain", systemImage: "lock")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SkillDetailSection(title: "Value") {
                    HStack(spacing: Metrics.spacingM) {
                        Text(revealed ?? String(repeating: "•", count: 16))
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: Metrics.spacingM)
                        Button(revealed == nil ? "Show" : "Hide", action: toggleReveal)
                            .controlSize(.small)
                        Button("Copy", action: copyValue)
                            .controlSize(.small)
                    }
                }

                SkillDetailSection(title: "Use It") {
                    VStack(alignment: .leading, spacing: Metrics.spacingL) {
                        SecretUsageRow(
                            title: "In your shell",
                            detail: "Add this to ~/.zshenv in place of the plain-text line.",
                            snippet: SecretVault.exportLine(name)
                        )
                        SecretUsageRow(
                            title: "For one command or MCP server",
                            detail: "The key exists only while that process runs. Swap in your server's own command.",
                            snippet: SecretVault.wrappedCommand(name)
                        )
                        Text("macOS asks before handing the key to anything but Clove. Choose Allow to be asked every time, or Always Allow to stop asking.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Metrics.spacingXL)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(name)
        .toolbar {
            ToolbarItem {
                Button("Delete", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                    .help("Delete this key from the Keychain")
            }
        }
        .confirmationDialog("Delete \(name)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Key", role: .destructive) { model.secrets.delete(name) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Anything that reads it from the Keychain stops working until you save it again.")
        }
    }

    private func toggleReveal() {
        if revealed != nil {
            revealed = nil
            return
        }
        Task { revealed = await model.secrets.reveal(name) }
    }

    private func copyValue() {
        Task {
            guard let value = await model.secrets.reveal(name) else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        }
    }
}
