import SwiftUI

struct SecretsList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var secrets = model.secrets

        ListPage(selection: $secrets.selection, order: secrets.items.map(\.id)) {
            PageHeader(title: "Secrets", summary: "API keys stored in your Keychain instead of a dotfile. macOS asks before anything uses one.")

            if !secrets.findings.isEmpty {
                PlaintextBanner(count: secrets.findings.count) {
                    secrets.selection = nil
                    secrets.isShowingFindings = true
                }
                .clipShape(.rect(cornerRadius: 14, style: .continuous))
            }

            if !secrets.items.isEmpty {
                ListSection(title: "Keys", note: secrets.items.count.formatted()) {
                    ForEach(secrets.items) { item in
                        SelectableRow(id: item.id, selection: $secrets.selection) {
                            HStack(spacing: Metrics.spacingM) {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.Vivid.yellow)
                                    .frame(width: 18)
                                Text(item.name)
                                    .codeLabel(13)
                                    .foregroundStyle(Palette.ink)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: Metrics.spacingS)
                                if let updated = item.updatedAt {
                                    Text("Updated \(updated, format: .relative(presentation: .named))")
                                        .monoLabel(11)
                                        .foregroundStyle(Palette.inkSecondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Secrets")
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
