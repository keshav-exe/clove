import SwiftUI

struct SecretsList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var secrets = model.secrets

        List(selection: $secrets.selection) {
            ForEach(secrets.items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body.monospaced().weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let updated = item.updatedAt {
                        Text("Updated \(updated, format: .relative(presentation: .named))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)
                .tag(item.id)
            }
        }
        .listStyle(.inset)
        .navigationTitle("Secrets")
        .safeAreaInset(edge: .top, spacing: 0) {
            if !secrets.findings.isEmpty {
                PlaintextBanner(count: secrets.findings.count) {
                    secrets.selection = nil
                }
            }
        }
        .overlay {
            if secrets.items.isEmpty {
                CalmEmptyState(
                    title: "No keys yet",
                    message: secrets.loadError ?? "Keys you save here live in your Keychain, not a dotfile, and macOS asks before anything reads one. The plus button adds the first."
                ) {
                    SecretsArt()
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Add Key", systemImage: "plus") { secrets.isAdding = true }
                    .help("Save an API key to your Keychain")
            }
        }
        .sheet(isPresented: $secrets.isAdding) {
            AddSecretSheet()
                .environment(model)
        }
        .task {
            secrets.load()
        }
    }
}
